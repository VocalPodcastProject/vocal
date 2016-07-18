Name:           vocal
Version:        1.0
Release:        1%{?dist}
Summary:        A beautiful podcast client for the modern free desktop
License:        GPLv3
URL:            http://vocalproject.net
Source0:        ~/nathan/vocal.tar.gz

BuildRequires: cmake
BuildRequires: gtk3-devel >= 3.14
BuildRequires: vala-devel
BuildRequires: intltool
BuildRequires: glib2-devel
BuildRequires: sqlite-devel
BuildRequires: libgee06-devel
BuildRequires: libnotify-devel
BuildRequires: clutter-gtk-devel
BuildRequires: clutter-devel
BuildRequires: gstreamer1-devel
BuildRequires: gstreamer1-plugins-base-devel
BuildRequires: desktop-file-utils

%description
A beautiful podcast client for GNU/Linux that features
audio and video playback, smart library management,
automatic feed checking and downloads, and much more.

%prep
%setup -q

%build
cmake -DCMAKE_INSTALL_PREFIX=/usr
make %{?_smp_mflags}

%install
%make_install

%post
/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :
/usr/bin/update-desktop-database &> /dev/null || :

%postun
if [ $1 -eq 0 ] ; then
    /usr/bin/glib-compile-schemas %{_datadir}/glib-2.0/schemas &> /dev/null || :
    /bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null
    /usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :
    /usr/bin/update-desktop-database &> /dev/null || :
fi

%posttrans
/usr/bin/glib-compile-schemas %{_datadir}/glib-2.0/schemas &> /dev/null || :
/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

%files
%doc AUTHORS COPYING README.md
%{_bindir}/%{name}
%{_datadir}/%{name}/
%{_datadir}/glib-2.0/schemas/net.launchpad.vocal.gschema.xml
%{_datadir}/appdata/%{name}.desktop.appdata.xml
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/*/*
%{_datadir}/locale-langpack/*/*

%changelog
* Sun Apr 12 2015 Nathan Dyer <mail@nathandyer.me> 1.0-1
- Initial Release
