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
	version => "0.2",
	summary => "Perl plugin that provides various notifications through KDialog.",
	description => "Provides notifications through KDialog for the following events:\n" .
				"- message received\n" .
				"- buddy signed on\n" .
				"- buddy signed off\n" .
				"\nThis program is offered under the terms of the GPL (version 2 or later). No warranty is provided for this program.",
	author => "mrovi <mrovi\@interfete-web-club.com>",
	url => "http://pidgin.im",
	load => "plugin_load",
	unload => "plugin_unload",
	prefs_info => "prefs_info_handler"
);

sub plugin_init {
	return %PLUGIN_INFO;
}

sub plugin_load {
	my $plugin = shift;
	Purple::Debug::info("testplugin", "plugin_load() - Test Plugin Loaded.\n");

	Purple::Prefs::add_none("/plugins/core/perl_knotifications");
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/popup_msg_in_enable", 1);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/popup_signed_on_enable", 1);
	Purple::Prefs::add_bool("/plugins/core/perl_knotifications/popup_signed_off_enable", 1);
	Purple::Prefs::add_int("/plugins/core/perl_knotifications/popup_duration", 5);

	$no_signed_on_popups = 0;
	$no_signed_on_popups_timeout = 0;

	Purple::Signal::connect(Purple::Conversations::get_handle(),
		"receiving-im-msg", $plugin, \&receiving_im_msg_handler, 0);
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
	Purple::Debug::info("testplugin", "plugin_unload() - Test Plugin Unloaded.\n");
}

sub prefs_info_handler {
	$frame = Purple::PluginPref::Frame->new();

	$ppref = Purple::PluginPref->new_with_name_and_label(
		"/plugins/core/perl_knotifications/popup_msg_in_enable", "Notification for received messages");
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

	return $frame;
}

sub receiving_im_msg_handler {
	my ($account, $sender, $message, $conv, $flags, $data) = @_;

	my $duration = Purple::Prefs::get_int("/plugins/core/perl_knotifications/popup_duration");

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/popup_msg_in_enable")) {
		if (!$conv->has_focus()) {
			system("kdialog --title \"Message received\" --passivepopup \"$sender: $message\" $duration");
		}
	}
}

sub buddy_signed_on_handler {
	my ($buddy) = @_;

	my $duration = Purple::Prefs::get_int("/plugins/core/perl_knotifications/popup_duration");

	#Purple::Debug::misc("knotifications", "buddy on (no_signed_on_popups == $no_signed_on_popups)\n");

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/popup_signed_on_enable") && $no_signed_on_popups == 0 && time() > $no_signed_on_popups_timeout) {
		my $name = $buddy->get_name();
		my $alias = $buddy->get_server_alias();

		if ($name ne $alias) {
			system("kdialog --title \"Buddy signed on\" --passivepopup \"$alias ($name)\" $duration");
		} else {
			system("kdialog --title \"Buddy signed on\" --passivepopup \"$name\" $duration");
		}
	}
}

sub buddy_signed_off_handler {
	my ($buddy) = @_;

	my $duration = Purple::Prefs::get_int("/plugins/core/perl_knotifications/popup_duration");

	if (Purple::Prefs::get_bool("/plugins/core/perl_knotifications/popup_signed_off_enable")) {
		my $name = $buddy->get_name();
		my $alias = $buddy->get_server_alias();
		if ($name ne $alias) {
			system("kdialog --title \"Buddy signed off\" --passivepopup \"$alias ($name)\" $duration");
		} else {
			system("kdialog --title \"Buddy signed off\" --passivepopup \"$name\" $duration");
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
