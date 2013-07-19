Updating Fedora for hydra-jetty
-------------------------------

Replace fedora.war, fedora-demo.war, fop.war, imagemanip.war, and saxon.war in webapps/ (use the official artifacts from Maven Central or Sourceforge so that the checksums are not altered).

Update Fedora version number in README.txt

The install of Fedora should use
	fedora.admin.pass: fedoraAdmin
	ssl.available: false
	servlet.engine: other
	database: included
	xacml.enabled (policy enforcement): false

Remove all the *.wars from $FEDORA_HOME/install

Update port references from 8080 to 8983 (fedora.fcfg, spring/web.properties)

Replace all absolute paths for FEDORA_HOME (in fedora.fcfg, akubra-llstore.xml, install.properties) with the relative path, "fedora/default"

Copy fedora/default to fedora/test, now replacing fedora/default paths with fedora/test
