# Copyright (C) 2010 mrovi@interfete-web-club.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02111-1301, USA.

use Purple;

%PLUGIN_INFO = (
	perl_api_version => 2,
	name => "KDE Notifications",
	version => "0.3.4",
	summary => "Perl plugin that provides various notifications through KDialog or libnotify.",
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
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/libnotify", 0);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/show_icon", 1);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/show_buddy_icon", 1);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/show_protocol_icon", 1);
	Purple::Prefs::add_string("/plugins/core/perl_knotifications/protocol_icons_path", "/usr/share/pixmaps/pidgin/protocols/48/");

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
		"/plugins/core/perl_knotifications/protocol_icons_path", "Path for protocol icons (must end with /)");
	$frame->add($ppref);

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/libnotify", "Use libnotify (gnome style) instead of kdialog");
	$frame->add($ppref);

	return $frame;
}

sub show_popup {
	my ($title, $text, $duration, $icon) = @_;
	# replace non-(alphanumeric _ & # ;) with the corresponding HTML escape code
	$text =~ s/([^\w&#;])/'&#'.ord($1).';'/ge;
	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/libnotify")) {
		$duration = $duration * 1000;
		if ($icon) {
			system("notify-send -u low -t $duration -i $icon \"$title\" \"$text\" &");
		} else {
			system("notify-send -u low -t $duration \"$title\" \"$text\" &");
		}
	} else {
		if ($icon) {
			system("kdialog --nograb --title \"$title\" --icon $icon --passivepopup \"$text\" $duration &");
		} else {
			system("kdialog --nograb --title \"$title\" --passivepopup \"$text\" $duration &");
		}
	}
	#Purple::Debug::misc("knotifications", "kdialog --nograb --title \"$title\" --passivepopup \"$text\" $duration & \n");
}

sub get_icon {
	my ($buddy, $account) = @_;

	if (!Purple::Prefs::get_bool("/plugins/core/perl_knotifications/show_icon")) {
		return null;
	}

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/show_buddy_icon")) {
		if ($buddy) {
			my $icon = $buddy->get_icon();
			if ($icon) {
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

		my $protocol_icon = null;
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
		}
	}

	return "pidgin";
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
			show_popup("Message received", "$sender: $message", $duration, get_icon($buddy, $account));
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
					show_popup("Message received", "$sender: $message", $duration, get_icon($buddy, $account));
				}
			} else {
				show_popup("Message received", "$sender: $message", $duration, get_icon($buddy, $account));
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

		if ($name ne $alias) {
			show_popup("Buddy signed on", "$alias ($name)", $duration, get_icon($buddy));
			#system("kdialog --nograb --title \"Buddy signed on\" --passivepopup \"$alias ($name)\" $duration &");
		} else {
			show_popup("Buddy signed on", "$name", $duration, get_icon($buddy));
			#system("kdialog --nograb --title \"Buddy signed on\" --passivepopup \"$name\" $duration &");
		}
	}
}

sub buddy_signed_off_handler {
	my ($buddy) = @_;

	my $duration = Purple::Prefs::get_int("/plugins/core/perl_knotifications/popup_duration");

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/popup_signed_off_enable")) {
		my $name = $buddy->get_name();
		my $alias = $buddy->get_alias();
		if ($name ne $alias) {
			show_popup("Buddy signed off", "$alias ($name)", $duration, get_icon($buddy));
			#system("kdialog --nograb --title \"Buddy signed off\" --passivepopup \"$alias ($name)\" $duration &");
		} else {
			show_popup("Buddy signed off", "$name", $duration, get_icon($buddy));
			#system("kdialog --nograb --title \"Buddy signed off\" --passivepopup \"$name\" $duration &");
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
