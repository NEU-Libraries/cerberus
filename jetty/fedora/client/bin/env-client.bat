@echo off
setlocal

REM ---------------------------------------------------------------------------
REM Common environment checks and launcher for Fedora client scripts.
REM
REM Environment Variables:
REM   FEDORA_HOME: Required.  Used to determine the location of client classes
REM                and other resources required to run the utilities.
REM   JAVA_HOME  : Optional.  Used to determine the location of java.
REM                If JAVA_HOME is unspecified, will use FEDORA_JAVA_HOME.
REM                If FEDORA_JAVA_HOME is unspecified, will use java in PATH. 
REM ---------------------------------------------------------------------------

if not "%FEDORA_HOME%" == "" goto gotFedoraHome
echo ERROR: The FEDORA_HOME environment variable is not defined.
exit /B 1
:gotFedoraHome

if exist "%FEDORA_HOME%\client\fcrepo-client-admin-3.6.1.jar" goto clientJarFound
echo ERROR: fcrepo-client-admin-3.6.1.jar not found in %FEDORA_HOME%\client
exit /B 1
:clientJarFound

if not "%JAVA_HOME%" == "" goto setJavaFromJavaHome
if not "%FEDORA_JAVA_HOME%" == "" goto setJavaFromFedoraJavaHome
set JAVA=java
goto gotJava
:setJavaFromFedoraJavaHome
set JAVA="%FEDORA_JAVA_HOME%\bin\java"
goto gotJava
:setJavaFromJavaHome
set JAVA="%JAVA_HOME%\bin\java"
:gotJava

set CP="%FEDORA_HOME%\client\bin;%FEDORA_HOME%\client\fcrepo-client-admin-3.6.1.jar;%FEDORA_HOME%\client\cxf-bundle-2.6.2.jar"
set OPTS=-Djava.endorsed.dirs="%FEDORA_HOME%\client\lib"
set OPTS=%OPTS% -Djavax.net.ssl.trustStore="%FEDORA_HOME%\client\truststore"
set OPTS=%OPTS% -Djavax.net.ssl.trustStorePassword=tomcat
set OPTS=%OPTS% -Djavax.xml.parsers.DocumentBuilderFactory=org.apache.xerces.jaxp.DocumentBuilderFactoryImpl
set OPTS=%OPTS% -Djavax.xml.parsers.SAXParserFactory=org.apache.xerces.jaxp.SAXParserFactoryImpl
set OPTS=%OPTS% -Dfedora.home="%FEDORA_HOME%"

%JAVA% -Xms64m -Xmx96m -cp %CP% %OPTS% %*
