# Copyright (C) 2010 mrovi@interfete-web-club.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02111-1301, USA.

############
# Changelog
# * Added support for masking sign on/off events for certain buddies
# * Added update checking at startup
#
############

use Purple;
use HTML::Entities;

%PLUGIN_INFO = (
	perl_api_version => 2,
	name => "Growl notifications",
	version => "0.3.6",
	summary => "Perl plugin that provides various notifications through Growl for Windows.",
	description => "Provides notifications for the following events:\n" .
				"- message received\n" .
				"- buddy signed on\n" .
				"- buddy signed off\n" .
				"\nThis program is offered under the terms of the GPL (version 2 or later). No warranty is provided for this program.",
	author => "mrovi <mrovi\@interfete-web-club.com>",
	url => "http://code.google.com/p/pidgin-knotifications",
	load => "plugin_load",
	unload => "plugin_unload",
	prefs_info => "prefs_info_handler"
);

sub plugin_init {
	return %PLUGIN_INFO;
}

sub plugin_load {
	my $plugin = shift;
	Purple::Debug::info("knotifications", "plugin_load() - Test Plugin Loaded.\n");

	Purple::Prefs::add_none("/plugins/core/perl_knotifications");
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/popup_msg_in_enable", 1);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/popup_chat_in_enable", 1);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/popup_chat_filter_my_nick", 1);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/popup_signed_on_enable", 1);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/popup_signed_off_enable", 1);
	Purple::Prefs::add_int("/plugins/core/perl_knotifications/popup_duration", 5);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/show_icon", 1);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/show_buddy_icon", 1);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/show_protocol_icon", 1);
	Purple::Prefs::add_string("/plugins/core/perl_knotifications/protocol_icons_path", "C:\\Program Files (x86)\\Pidgin\\pixmaps\\pidgin\\protocols\\48\\");
	Purple::Prefs::add_string("/plugins/core/perl_knotifications/growl_command", "C:\\Program Files (x86)\\Growl for Windows\\growlnotify.exe");
	Purple::Prefs::add_string("/plugins/core/perl_knotifications/signon_regex", '^(example_buddy_id_1|example_buddy_id_2|Example Buddy Name)$');
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/check_for_updates", 1);

	$no_signed_on_popups = 0;
	$no_signed_on_popups_timeout = 0;

	Purple::Signal::connect(Purple::Conversations::get_handle(),
		"received-im-msg", $plugin, \&received_im_msg_handler, 0);
	Purple::Signal::connect(Purple::Conversations::get_handle(),
		"received-chat-msg", $plugin, \&received_chat_msg_handler, 0);
	Purple::Signal::connect(Purple::BuddyList::get_handle(),
		"buddy-signed-on", $plugin, \&buddy_signed_on_handler, 0);
	Purple::Signal::connect(Purple::BuddyList::get_handle(),
		"buddy-signed-off", $plugin, \&buddy_signed_off_handler, 0);

	Purple::Signal::connect(Purple::Connections::get_handle(),
		"signing-on", $plugin, \&signing_on_handler, 0);
	Purple::Signal::connect(Purple::Connections::get_handle(),
		"signed-on", $plugin, \&signed_on_handler, 0);
	
	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/check_for_updates")) {
		check_for_updates();
	}
}

sub plugin_unload {
	my $plugin = shift;
	Purple::Debug::info("knotifications", "plugin_unload() - Test Plugin Unloaded.\n");
}

sub prefs_info_handler {
	$frame = Purple::PluginPref::Frame->new();

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/popup_msg_in_enable", "Notification for received messages");
	$frame->add($ppref);

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/popup_chat_in_enable", "Notification for received chat messages");
	$frame->add($ppref);

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/popup_chat_filter_my_nick", "Show chat notifications only when someone mentions my nick");
	$frame->add($ppref);

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/popup_signed_on_enable", "Notification for buddy sign on events");
	$frame->add($ppref);

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/popup_signed_off_enable", "Notification for buddy sign off events");
	$frame->add($ppref);
	
	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/signon_regex", "Disable sign on/off notifications for these buddies (regex)");
	$frame->add($ppref);

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/popup_duration", "Popup duration (seconds)");
	$ppref->set_bounds(1, 3600);
	$frame->add($ppref);

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/show_icon", "Display icons");
	$frame->add($ppref);

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/show_buddy_icon", "Display buddy icons if possible");
	$frame->add($ppref);

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/show_protocol_icon", "Fallback to protocol icons");
	$frame->add($ppref);

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/protocol_icons_path", "Path for protocol icons (must end with \\)");
	$frame->add($ppref);
	
	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/growl_command", "Command to run growlnotify.exe");
	$frame->add($ppref);
	
	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/check_for_updates", "Check for updates on startup");
	$frame->add($ppref);

	return $frame;
}

sub check_for_updates {
	my $growl = Purple::Prefs::get_string("/plugins/core/perl_knotifications/growl_command");
	my $duration = 30;
	my $icon = 0;
	my $version = $PLUGIN_INFO{ 'version' };
	
	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/show_protocol_icon")) {
		$icon = Purple::Prefs::get_string("/plugins/core/perl_knotifications/protocol_icons_path") . '../../buttons/info.png';
	}
	
	if (fork() == 0) {
		use LWP::UserAgent;
		use HTTP::Request;

		$request = HTTP::Request->new(GET => 'http://pidgin-knotifications.googlecode.com/svn/trunk/latest-win-version.txt');

		$ua = LWP::UserAgent->new();
		$response = $ua->request($request);
		$latest = $response->decoded_content();
		
		if ($latest =~ '^\d\.\d\.\d$' && $latest ne $version) {
			show_popup('Pidgin Growl Notifications: update available (' . $latest . ')',
				'Click to open download page',
				$duration,
				$icon,
				'http://code.google.com/p/pidgin-knotifications/downloads/detail?name=knotifications-' . $latest . '-win.pl',
				$growl);
		}
		exit(0);
	}
}

sub forkexec {
	my ($cmd, @args) = @_;
	# Purple::Debug::misc("knotifications", "running: $cmd @args\n");
	if (fork() == 0) {
		exec($cmd, @args);
	}
}

sub show_popup {
	my ($title, $text, $duration, $icon, $url, $growl) = @_;
	
	decode_entities($title);
	decode_entities($text);
		
	# windows cmd and growlnotify stuff
	$text =~ s/"/''/g;
	$text =~ s/\\n/\\\\n/g;
	$text =~ s/(\\+)$/$1$1/g;
	if ($icon) {
		if ($url) {
			forkexec($growl, "/i:$icon", "/t:$title", "/cu:$url", $text);
		} else {
			forkexec($growl, "/i:$icon", "/t:$title", $text);
		}
	} else {
		if ($url) {
			forkexec($growl, "/t:$title", "/cu:$url", $text);
		} else {
			forkexec($growl, "/t:$title", $text);
		}
	}
}

sub get_icon {
	my ($buddy, $account) = @_;

	if (!Purple::Prefs::get_bool("/plugins/core/perl_knotifications/show_icon")) {
		return 0;
	}

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/show_buddy_icon")) {
		if ($buddy) {
			my $icon = $buddy->get_icon();
			if ($icon && !($icon =~ m/\.icon$/)) {
				return $icon->get_full_path();
			}
		}
	}

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/show_protocol_icon")) {
		my $protocol = "";
		if ($buddy) {
			$protocol = $buddy->get_account()->get_protocol_id();
		} else {
			if ($account) {
				$protocol = $account->get_protocol_id();
			}
		}
		Purple::Debug::misc("knotifications", "protocol id: $protocol\n");

		my $protocol_icon = 0;
		if ($protocol eq 'prpl-aim') { $protocol_icon = 'aim.png'; }
		if ($protocol eq 'prpl-bonjour') { $protocol_icon = 'bonjour.png'; }
		if ($protocol eq 'prpl-gg') { $protocol_icon = 'gadu-gadu.png'; }
		if ($protocol eq 'prpl-icq') { $protocol_icon = 'icq.png'; }
		if ($protocol eq 'prpl-irc') { $protocol_icon = 'irc.png'; }
		if ($protocol eq 'prpl-jabber') { $protocol_icon = 'jabber.png'; }
		if ($protocol eq 'prpl-msn') { $protocol_icon = 'msn.png'; }
		if ($protocol eq 'prpl-myspace') { $protocol_icon = 'myspace.png'; }
		if ($protocol eq 'prpl-novell') { $protocol_icon = 'novell.png'; }
		if ($protocol eq 'prpl-qq') { $protocol_icon = 'qq.png'; }
		if ($protocol eq 'prpl-silc') { $protocol_icon = 'silc.png'; }
		if ($protocol eq 'prpl-simple') { $protocol_icon = 'simple.png'; }
		if ($protocol eq 'prpl-yahoo') { $protocol_icon = 'yahoo.png'; }
		if ($protocol eq 'prpl-yahoojp') { $protocol_icon = 'yahoojp.png'; }
		if ($protocol eq 'prpl-zephyr') { $protocol_icon = 'zephyr.png'; }

		if ($protocol_icon) {
			return Purple::Prefs::get_string("/plugins/core/perl_knotifications/protocol_icons_path") . $protocol_icon;
		} else {
			return Purple::Prefs::get_string("/plugins/core/perl_knotifications/protocol_icons_path") . '../../tray/hicolor/48x48/status/pidgin-tray-pending.png';
		}
	}
	
	my $generic = Purple::Prefs::get_string("/plugins/core/perl_knotifications/protocol_icons_path") . '../../tray/hicolor/48x48/status/pidgin-tray-pending.png';
	if (-e $generic) {
		return $generic;
	}

	return 0;
}

sub received_im_msg_handler {
	my ($account, $sender, $message, $conv, $flags, $data) = @_;

	Purple::Debug::misc("knotifications", "received_im_msg_handler(@_)\n");

	$message =~ s/<[^>]+>//g;

	my $duration = Purple::Prefs::get_int("/plugins/core/perl_knotifications/popup_duration");
	my $buddy = Purple::Find::buddy($account, $sender);
	if ($buddy) {
		my $name = $buddy->get_name();
		my $alias = $buddy->get_alias();
		if ($name ne $alias) {
			$sender = "$alias ($name)";
		} else {
			$sender = "$name";
		}
	}

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/popup_msg_in_enable")) {
		if (!defined $conv || !$conv->has_focus()) {
			show_popup("Message received", "$sender: $message", $duration, get_icon($buddy, $account), null,
				Purple::Prefs::get_string("/plugins/core/perl_knotifications/growl_command"));
		}
	}
}

sub received_chat_msg_handler {
	my ($account, $sender, $message, $conv, $flags, $data) = @_;

	Purple::Debug::misc("knotifications", "received_chat_msg_handler(@_)\n");

	$message =~ s/<[^>]+>//g;

	my $duration = Purple::Prefs::get_int("/plugins/core/perl_knotifications/popup_duration");
	my $buddy = Purple::Find::buddy($account, $sender);
	if ($buddy) {
		my $name = $buddy->get_name();
		my $alias = $buddy->get_alias();
		if ($name ne $alias) {
			$sender = "$alias ($name)";
		} else {
			$sender = "$name";
		}
	}

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/popup_chat_in_enable")) {
		if (!defined $conv || !$conv->has_focus()) {
			if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/popup_chat_filter_my_nick")) {
				if (index($message, $conv->get_chat_data->get_nick()) >= 0) {
					show_popup("Message received", "$sender: $message", $duration, get_icon($buddy, $account), null,
						Purple::Prefs::get_string("/plugins/core/perl_knotifications/growl_command"));
				}
			} else {
				show_popup("Message received", "$sender: $message", $duration, get_icon($buddy, $account), null,
					Purple::Prefs::get_string("/plugins/core/perl_knotifications/growl_command"));
			}
		}
	}
}

sub buddy_signed_on_handler {
	my ($buddy) = @_;

	my $duration = Purple::Prefs::get_int("/plugins/core/perl_knotifications/popup_duration");

	#Purple::Debug::misc("knotifications", "buddy on (no_signed_on_popups == $no_signed_on_popups)\n");

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/popup_signed_on_enable") && $no_signed_on_popups == 0 && time() > $no_signed_on_popups_timeout) {
		my $name = $buddy->get_name();
		my $alias = $buddy->get_alias();

		my $regex_ignore = Purple::Prefs::get_string("/plugins/core/perl_knotifications/signon_regex");
		if ($name =~ m/$regex_ignore/ || $alias =~ m/$regex_ignore/) {
			Purple::Debug::misc("knotifications", "Ignored (regex) sign on event for $alias ($name)\n");
		} else {
			if ($name ne $alias) {
				show_popup("Buddy signed on", "$alias ($name)", $duration, get_icon($buddy), null,
					Purple::Prefs::get_string("/plugins/core/perl_knotifications/growl_command"));
			} else {
				show_popup("Buddy signed on", "$name", $duration, get_icon($buddy), null,
					Purple::Prefs::get_string("/plugins/core/perl_knotifications/growl_command"));
			}
		}
	}
}

sub buddy_signed_off_handler {
	my ($buddy) = @_;

	my $duration = Purple::Prefs::get_int("/plugins/core/perl_knotifications/popup_duration");

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/popup_signed_off_enable")) {
		my $name = $buddy->get_name();
		my $alias = $buddy->get_alias();
		
		my $regex_ignore = Purple::Prefs::get_string("/plugins/core/perl_knotifications/signon_regex");
		if ($name =~ m/$regex_ignore/ || $alias =~ m/$regex_ignore/) {
			Purple::Debug::misc("knotifications", "Ignored (regex) sign on event for $alias ($name)\n");
		} else {
			if ($name ne $alias) {
				show_popup("Buddy signed off", "$alias ($name)", $duration, get_icon($buddy), null,
					Purple::Prefs::get_string("/plugins/core/perl_knotifications/growl_command"));
			} else {
				show_popup("Buddy signed off", "$name", $duration, get_icon($buddy), null,
					Purple::Prefs::get_string("/plugins/core/perl_knotifications/growl_command"));
			}
		}
	}
}

sub signing_on_handler
{
	my $conn = shift;
	#Purple::Debug::misc("knotifications", "signing-on (" . $conn->get_account()->get_username() . ")\n");
	$no_signed_on_popups = 1;
}

sub signed_on_handler
{
	my $conn = shift;
	#Purple::Debug::misc("knotifications", "signed-on (" . $conn->get_account()->get_username() . ")\n");
	$no_signed_on_popups = 0;
	$no_signed_on_popups_timeout = time() + 3;
}
