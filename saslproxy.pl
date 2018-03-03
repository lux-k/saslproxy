#/usr/bin/perl
# SMTP SASL Authentication proxy for SMTP clients
# Kevin Lux, webmaster@datadragon.com
# $Id: saslproxy.pl,v 1.2 2008/12/08 17:12:36 perp Exp $
# This script is meant to act as a SMTP proxy for the following condition:
#	The sender uses SMTP but does not understand how to do SASL authentication
#	The server requires SASL authentication to send.
# You might have to combine this with stunnel if your server also requires TLS.
# If that's the case, configure this script's relay to be stunnel and then configure stunnel
# to connect to the actual mail server.
# 
# An stunnel config to do that would look like this:
# --- start ---
# client = yes
#
# [securesmtp]
# accept  = 25
# connect = mail.yourserver.com:25
# protocol = smtp
# --- end ---
#
# You can use test.pl to send a simple mail message to double check that
# the proxy is working.

use strict;
use Socket;
use MIME::Base64;

# identity settings
#
# the user name to auth as
my $user = "user";
# the password to auth with
my $passwd = "password";

# network settings
#
# address to bind, leave blank for all interfaces
my $localaddr = "localhost";
# which port this proxy should listen on
my $listenport = 2525;
# server we should relay to
my $relay = "10.0.2.40";
# server port to relay to
my $relayport = 25;
# timeout to wait for recv'ing data
my $timeout = 30;

#
# no changes needed below
#

$| = 1;
no strict qw/refs/;

# setup the listening socket
socket(serversock(), PF_INET, SOCK_STREAM, getprotobyname('tcp')) || die "socket: $!";
setsockopt(serversock(), SOL_SOCKET, SO_REUSEADDR, pack("l", 1)) || die "setsockopt: $!";
bind(serversock(), sockaddr_in($listenport, $localaddr && inet_aton($localaddr) || INADDR_ANY)) || die "bind: $!";
listen(serversock(),SOMAXCONN) || die "listen: $!";

logmsg("server started on port $listenport");

# enter the main accept loop
while (1) {
	# accept a connection
	my $paddr = accept(clientsock(), serversock());
	if (fork() == 0) {
		# and fork a child process to deal with it
		my ($port,$iaddr) = sockaddr_in($paddr);
		my $name = gethostbyaddr($iaddr, AF_INET);
		logmsg("connection from $name [",inet_ntoa($iaddr), "] at port $port");	

		# connect to the mail relay
		my $paddr   = sockaddr_in($relayport, inet_aton($relay));
		socket(serversock(), PF_INET, SOCK_STREAM, getprotobyname('tcp')) || die "socket: $!";
		connect(serversock(), $paddr)    || die "connect: $!";

		# enter the dialog loop
		while (1) {
			writeclient(waitserver());
			WAITCLIENT:
			my $line = waitclient();
			if ($line =~ m/^ehlo/i) {
				# reject esmtp support to the client
				# mostly because i'm too lazy to look up the esmtp protocol
				# the client will come back with a normal helo per the smtp rfc
				writeclient("501 EHLO not supported\r\n");
				goto WAITCLIENT;
			} elsif ($line =~ m/^helo /i) {
				writeserver($line);
				# reply to helo line
				my $line = waitserver();
				# inject authentication
				writeserver("AUTH PLAIN\r\n");
				waitserver();
				writeserver(encode_base64("\0$user\0$passwd"));
				waitserver();
				writeclient($line);
				goto WAITCLIENT;
			} elsif ($line =~ m/^data\r?\n$/i) {
				# send data line to server
				writeserver($line);
				# wait for Ok line from server and send to client
				writeclient(waitserver());
				my $message = "";
				# loop until message contains the end marker (\r?\n.\r?\n)
				while ($message !~ /\r?\n\.\r?\n$/) {
					my $line = waitclient();
					$message .= $line;
					writeserver($line);				
				}
			} elsif ($line =~ m/quit\r?\n$/) {
				# send quit line
				writeserver($line);
				# return server response
				writeclient(waitserver());
				# wait for close
				waitserver();
			} else {
				writeserver($line);
			}
		}

		close serversock();
		close clientsock();

		exit;
	}

	close Client;
}


sub clientsock {
	return "Client";
}

sub serversock {
	return "Server";
}

sub logmsg {
	my $msg = "@_";
	$msg =~ s/\r?\n$//g;
	print "$0 $$ [", scalar localtime,"]: ", $msg , "\n";
}

sub waitclient {
	return waitsocket(clientsock(), "client");
}

sub waitserver {
	return waitsocket(serversock(), "server");
}

sub writeclient {
	syswrite(clientsock(), shift);
}

sub writeserver {
	syswrite(serversock(), shift);
}

sub waitsocket {
	my $socket = shift;
	my $name = shift;
	# line received
	my $line = "";
	# bytes read in 1 read
	my $read = -1;
	# characters read
	my $data;
	my $myvec;
	vec($myvec, fileno($socket), 1)=1;
	while (!($line =~ m/\n$/ || $read == 0)) {
		eval {
			if (select($myvec,undef,undef,$timeout)) {
				$read = sysread($socket, $data, 16);
			} else {
				logmsg "read timeout on $socket";
			}
		};

		if ($@ || $read <= 0) {
			logmsg "closing $socket\n";
			exit;
		}
		
		$line .= $data;
	}

	logmsg "Wait on $name read ", length($line), " bytes; $line\n";
	return $line;
}

