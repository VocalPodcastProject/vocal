project('vocal', ['c', 'vala'],
          version: '4.0.0',
    meson_version: '>= 0.59.0',
  default_options: [ 'warning_level=2',
                   ],
)

gnome = import('gnome')

i18n = import('i18n')
add_global_arguments([
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    '-w',
], language: 'c')

subdir('data')
subdir('src')
subdir('po')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
