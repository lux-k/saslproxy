#!/usr/bin/perl
# $Id: test.pl,v 1.2 2008/12/08 17:12:36 perp Exp $
use Net::SMTP;

my $destination = 'user@destination';

$smtp = Net::SMTP->new('localhost');

$smtp->mail('user@localhost');
$smtp->to($destination);

$smtp->data();
$smtp->datasend("To: $destination\n");
$smtp->datasend("Subject: Proxy test\n");
$smtp->datasend("\n");
$smtp->datasend("It worked!\n");
$smtp->dataend();

$smtp->quit;

