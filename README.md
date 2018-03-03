# This script is meant to act as a SMTP proxy for the following condition:
#       The sender uses SMTP but does not understand how to do SASL authentication
#       The server requires SASL authentication to send.
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
