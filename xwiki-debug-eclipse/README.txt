This is a Eclipse project used to easily debug a complete XWiki Enterprise (it can also be used for XWiki Enterprise Manager since it comes with it dependencies).

= PREREQUISITES =

* You need M2EClipse 0.9.9 or superior.

= INSTALL =

Make sure to import the project as existing Eclipse project and not as Maven project otherwise M2Eclipse will try to rebuild the configuration and could break some things.

[OPTIONAL] By default xwiki-debug-eclipse find xwiki-platform repository in ${PROJECT_LOC}/../xwiki-platform (which mean in the same parent folder than where you cloned xwiki-debug-eclipse). If that's not true for you, you can change it by going to project Properties -> Resources -> Linked Resources.

== Set configuration ==

This project comes with some example configuration you need to copy/past and set as you need it to:
* src/main/webapp/WEB-INF/xwiki.cfg.default -> src/main/webapp/WEB-INF/xwiki.cfg
* src/main/webapp/WEB-INF/xwiki.properties.default -> src/main/webapp/WEB-INF/xwiki.properties
* src/main/webapp/WEB-INF/hibernate.<database>.cfg.xml.default -> src/main/webapp/WEB-INF/hibernate.cfg.xml

= TODO =

* add support for GWT WYSIWYG (and any other GWT based module)