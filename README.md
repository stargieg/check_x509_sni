check_x509_sni
==================

This check plugin for Icinga2 / Icingaweb2 Keeps track 
of certificates as they are deployed in a network environment.

	$ ./check_x509_sni.sh -h
	Required parameters:
	   -l HOSTNAME A hosts name

	Optional parameters:
	  -w Warning Less remaining time results in state WARNING [25%]
	  -c Critical Less remaining time results in state CRITICAL [10%]
	  -p PORT ($port$) default 443
	  -s allow-self-signed Ignore if a certificate or its issuer has been self-signed

Threshold Definition
--------------------

Thresholds can either be defined relative (in percent) or absolute (time interval). Time intervals consist of a digit and an accompanying unit (e.g. “3M” are three months). Supported units are:

	Identifier 	Description
	y, Y 		Year
	M 		Month
	d, D 		Day
	h, H 		Hour
	m 		Minute
	s, S 		Second

Example
------------

	./check_x509_sni.sh -l example.org -w 25% -c 10%
	OK - example.org expires in 54 days|'example.org'=4691550s;1900800:;777600:;0;7775999	
	./check_x509_sni.sh -l example.org -w 100d -c 50d
	WARNING - example.org expires in 54 days|'example.org'=4691629s;8640000:;4320000:;0;7775999


Installation
------------

You need Icinga Certificate Monitoring packages for this script to work:

    apt-get install icinga-x509
