#!/usr/bin/perl
use WWW::Mechanize;
use HTML::Form;

use strict;
use warnings;

my $res = WWW::Mechanize->new->get("https://www.airvoicewireless.com/login");
my @forms = HTML::Form->parse($res);
foreach my $form (@forms) {
	print $form->dump:
}
