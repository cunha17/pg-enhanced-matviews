#--
#-- SUB: message
#-- Log messages (displayed on postgresql console)
#--
sub message {
	#-- Function parameters
	my ($level, $msg) = @_;

	elog ($level, $msg);
}

sub error {
	#-- Function parameters
	my ($msg) = @_;

	message (ERROR, $msg);
}

sub warning {
	#-- Function parameters
	my ($msg) = @_;

	message (WARNING, $msg);
}

sub notice {
	#-- Function parameters
	my ($msg) = @_;

	if ($main::DEBUG) {
		message (NOTICE, $msg);
	}
}
