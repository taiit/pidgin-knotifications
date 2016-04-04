# KDE4, Gnome and Growl for Windows Notifications in Pidgin #

This is a notification plugin for Purple/Pidgin that provides notifications through KDialog or libnotify, when:

  * a buddy signs on
  * a buddy signs off
  * a message is received (if the conversation window is not focused).

The purpose of this plugin is to offer a better integration of Pidgin and the KDE 4 desktop. Support for libnotify (Gnome style) is also offered as an alternative.

An experimental version that uses Growl is provided for Windows. See the installation notes below.

# Features #
  * Shows notifications for buddy sign on, sign off and message received events
  * It is a Perl plugin -> **no compilation is needed**, just place it in Pidgin's plugin folder and it works
  * Configurable: you can disable/enable each type of notification and set the popup duration

# News #
Keep yourself updated by subscribing to the [RSS changelog feed](http://code.google.com/feeds/p/pidgin-knotifications/updates/basic).
Or browse the source code changelog in your browser [here](http://code.google.com/p/pidgin-knotifications/source/list).

# Linux Requirements #
This plugin is designed to work with Pidgin under Linux and KDE4 or Gnome. It is written in Perl, so make sure your version of Pidgin has Perl support; you can find out by going to **Pidgin->Help->About** and in the **Library support** section you must see **Perl: enabled**. If Perl is not enabled then it might be provided by your distribution in a different package, search for something like pidgin-perl.

You will also need Perl and KDE4. As an alternative to KDE, or if you want to use Gnome notifications under KDE, you must install libnotify (the notify-send command is required).

Perl must have support for HTML::Entities; this is usually provided in a package called perl-HTML-Parser.

# Linux Installation #
From the [Downloads](http://code.google.com/p/pidgin-knotifications/downloads/list) page, get the latest version of knotifications.pl and save it to ~/.purple/plugins (create the plugins directory if it does not exist), for example: /home/bob/.purple/plugins/knotifications.pl.

The Chromium browser might save the file with a wrong extension, knotifications.download. Make sure the file extension is correct, it must be **pl**: knotifications.pl.

You must then go to **Pidgin->Tools->Plugins** and enable KDE Notifications from the list.

# Windows installation #
  * Install [ActivePerl](http://developer.pidgin.im/wiki/Scripting%20and%20Plugins#WhydoesntmyPerlpluginshowupinthePluginsdialog)
  * Install [Growl for Windows](http://www.growlforwindows.com/gfw/default.aspx)
  * From the [Downloads](http://code.google.com/p/pidgin-knotifications/downloads/list) page, get the latest version of knotifications-win.pl and save it to C:\Users\yourusername\AppData\Roaming\.purple\plugins (create the plugins directory if it does not exist)
  * Open Pidgin, and enable the plugin. From its configuration page, make sure the paths to the Pidgin icon folder and the Growl folder are correct.

# Screenshots #
### Notification when a buddy signs on: ###
![http://pidgin-knotifications.googlecode.com/svn/trunk/wiki/snapshot1-signon.png](http://pidgin-knotifications.googlecode.com/svn/trunk/wiki/snapshot1-signon.png)

### Notification for a new message: ###
![http://pidgin-knotifications.googlecode.com/svn/trunk/wiki/snapshot2-message.png](http://pidgin-knotifications.googlecode.com/svn/trunk/wiki/snapshot2-message.png)

### Gnome (libnotify) notification: ###
![http://pidgin-knotifications.googlecode.com/svn/trunk/wiki/snapshot-libnotify1.png](http://pidgin-knotifications.googlecode.com/svn/trunk/wiki/snapshot-libnotify1.png)

### Windows (growlnotify) notification: ###
![http://pidgin-knotifications.googlecode.com/svn/trunk/wiki/notify-win.png](http://pidgin-knotifications.googlecode.com/svn/trunk/wiki/notify-win.png)

### Configuration page: ###
![http://pidgin-knotifications.googlecode.com/svn/trunk/wiki/snapshot3-config.png](http://pidgin-knotifications.googlecode.com/svn/trunk/wiki/snapshot3-config.png)

# User feedback and bugtracker #
Please see the [user feedback](UserFeedback.md) page.