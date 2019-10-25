%global appname com.github.needleandthread.vocal

Name:           vocal
Summary:        Powerful, beautiful, and simple podcast client
Version:        2.0.19
Release:        1%{?dist}
License:        GPLv3

URL:            https://github.com/needle-and-thread/%{name}
Source0:        %{url}/archive/%{version}/%{name}-%{version}.tar.gz

BuildRequires:  cmake
BuildRequires:  desktop-file-utils
BuildRequires:  gettext
BuildRequires:  intltool
BuildRequires:  libappstream-glib
BuildRequires:  vala >= 0.26.2

BuildRequires:  pkgconfig(clutter-gst-3.0)
BuildRequires:  pkgconfig(clutter-gtk-1.0)
BuildRequires:  pkgconfig(glib-2.0) >= 2.32
BuildRequires:  pkgconfig(gdk-x11-3.0)
BuildRequires:  pkgconfig(gee-0.8)
BuildRequires:  pkgconfig(granite)
BuildRequires:  pkgconfig(gstreamer-1.0)
BuildRequires:  pkgconfig(gstreamer-pbutils-1.0)
BuildRequires:  pkgconfig(gthread-2.0)
BuildRequires:  pkgconfig(gtk+-3.0)
BuildRequires:  pkgconfig(json-glib-1.0)
BuildRequires:  pkgconfig(libnotify)
BuildRequires:  pkgconfig(libsoup-2.4)
BuildRequires:  pkgconfig(libxml-2.0)
BuildRequires:  pkgconfig(sqlite3)
BuildRequires:  pkgconfig(unity)
BuildRequires:  pkgconfig(webkit2gtk-4.0)


%description
Vocal is a powerful, fast, and intuitive application that helps users
find new podcasts, manage their libraries, and enjoy the best that
independent audio and video publishing has to offer. Vocal features full
support for both episode downloading and streaming, native system
integration, iTunes store search and top 100 charts (with international
results support), iTunes link parsing, OPML importing and exporting, and
so much more. Plus, it has great smart features like automatically
keeping your library clean from old files, and the ability to set custom
skip intervals.


%prep
%autosetup


%build
# mark sources files and docs as NOT executable
for i in $(find -name "*.vala"); do chmod a-x $i; done
chmod a-x AUTHORS README.md COPYING

mkdir build && pushd build
%cmake ..
%make_build
popd


%install
pushd build
%make_install
popd

%find_lang vocal


%check
desktop-file-validate \
    %{buildroot}/%{_datadir}/applications/%{appname}.desktop

appstream-util validate-relax --nonet \
    %{buildroot}/%{_datadir}/appdata/%{appname}.appdata.xml


%post
/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :

%postun
if [ $1 -eq 0 ] ; then
    /bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null
    /usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :
fi

%posttrans
/usr/bin/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :


%files -f vocal.lang
%doc AUTHORS README.md
%license COPYING

%{_bindir}/vocal

%{_datadir}/appdata/%{appname}.appdata.xml
%{_datadir}/applications/%{appname}.desktop
%{_datadir}/glib-2.0/schemas/%{appname}.gschema.xml
%{_datadir}/icons/hicolor/*/apps/%{appname}*.svg
%{_datadir}/vocal/


%changelog
* Sun May 28 2017 Fabio Valentini <decathorpe@gmail.com> - 2.0.19-1
- Initial package.

