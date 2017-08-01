# CM/CDH Certificate Toolkit management

### DISCLAIMER

The use of this toolkit is not _officially_ supported. Before using it, ensure you understand SSL/TLS configuration for CM and CDH and review this entire doc ument. Also, make sure you pratice the use of the toolkit before using it in a critical environment.

If problems happen, resort to the [online Cloudera Documentation](http://www.cloudera.com/content/cloudera/en/documentation/core/latest/topics/sg_encryption.html) and complete the configuration manually.

If you have any questions or doubts ask at cert-toolkit@cloudera.com.

__USE AT YOUR OWN RISK. Feedback is appreciated at cert-toolkit@cloudera.com.__

### About

The configuration of SSL/TLS encryption through Cloudera Manager is currently a time consuming process with many moving parts scattered across multiple configuration pages. It requires a lot of attention to avoid configuration mistakes and time to get everything running correctly.

It also requires the creation and distribution of signed certificates across all the cluster nodes, which usually has to be done manually and without the help of CM.

The CertToolkit is a proof of concept and PS/FCE enablement toolkit for SSL/TLS configuration automation. It takes care of all the steps mentioned above in a single concise tool, with a central configuration file, making it much easier and quicker to configure SSL/TLS for CM and CDH correctly.

### Versions

The toolkit was initially created as a set of shell scripts and later ported to Python.

Version 1.1 is the former shell script implementation and is tagged as [`v1.1`](http://github.mtv.cloudera.com/CertTeam/CertToolkit/tree/v1.1) in the GitHub repository. This version is deprecated and not maintained any longer.

Version 2.x is the current and new Python implementation. Please prefer using this one.

### Features

 * __Single configuration file__ - all the configuration required is summarised in a single file: `defaults.yaml`
 * __3-step configuration process__ - the end-to-end SSL/TLS configuration can be executed in just a few [steps](#running-the-scripts)
 * __Supports addition of new nodes to the cluster__ - the script provides an easy way to add new hosts to a secured cluster without having to manually go through the configuration or restart the whole cluster
 * __Secures CM and CDH services__ - the toolkit configured SSL/TLS for Cloudera Manager as well as for selected CDH services. The services can be individually selected by editing the configuration file
 * __Enable and disable wire encryption at will__ - the toolkit allow you to quickly toggle the SSL/TLS configuration for CM and CDH services
 * __Openssl private CA and AD automation support__ - limited automation is provided for signing CSRs with either AD or a locally created OpenSSL CA
 * __Auto backup of certificates prior to each run__ - all files are automatically backed up before each script run to ensure previously generated certificates are not lost in case of problems

### To Do

* Improve logging to help with troubleshooting

### More information

Consider that the transfer of the private keys performed here may not be a long term solution (even though SSH in this approach used here). It would make more sense to have them extracted local to the system. Exercise caution if using in the field or in an untrusted network environment.

The set of scripts provides a way to automate the creation of java keystores, truststores and the certificate and key files necessary for Hue and CM agents across the cluster.  We recommend that scripts be run by an account other than `root`. That account will need `sudo` access to `root`.

The CM server will provide the "warehouse" for the keystores, truststores and certs necessary, and then once ready, push out to all cluster nodes over SSH/SCP.

### Recommended workflow

SSL/TLS encryption *can* be enabled for a cluster *with* or *without* Kerberos being enabled. When SSL/TLS is configured for CDH *services* without Kerberos some warnings will be shown in Cloudera Manager, recommending that Kerberos be enabled to further secure the cluster.

Furthermore, some encryption features can only be fully configured once Kerberos is enabled. Hence, we recommend that SSL/TLS only be enabled for __CDH services__ after Kerberos has been configured.

__However__, in a Kerberized cluster Cloudera Manager distributes Kerberos principals' keytabs to the cluster nodes upon starting services on them. These keytabs are *very sensitive* and we must ensure they are transferred securely across node. We recommend that SSL/TLS (preferrably level 3) be enabled for Cloudera Manager and agents __only__ before enabling Kerberos. This will ensure that keytabs are transferred to the cluster nodes over an encrypted channel.

We recommend that the order of steps to secure a CDH cluster be the following:
* Enable SSL/TLS for Cloudera Manager and agents __only__
  - To accomplish this using the toolkit, configure the SSL options for CDH services to "NO" (HDFS_SSL, HIVE_SSL, etc...) before running the `enable_tls` action
* [Enable Kerberos](http://tiny.cloudera.com/kerberos-wizard)
* Enable SSL/TLS for CDH Services
  - Configure the toolkit SSL options for CDH services to "YES" and re-run the `enable_tls` action

### Before you start

* Clone this repository in the homedir of the chosen user
* Edit the `defaults.yaml` file to reflect your environment and configuration choices 

### Prerequisites

* OS account with access to all the cluster nodes. This can be either one of:
  - Ordinary account able to sudo to root (recommended)
  - root

A setup script is provided with the CertToolkit to install the required software and Python packages.

### Setup

The `setup.sh` script, found at the root of the repository can be used to install the CertToolkit pre-requisites:

The syntax is:
```
bash setup.sh [virt_env_name]
```

When a virtual environment name is provided the setup script will create the virtual environment and install the necessary Python packages only in that environment, avoiding conflicts with existing Python setups. This is the recommended mode of operation.
If a virtual environment name is not provided the packages will be installed in the environment current Python deployment.

Example:
```
bash setup.sh env
```

NOTE: The setup script throws some "Warnings" during its execution, which can be safely ignored. If the script completes successfully it will show the following message at the end: "CertToolkit setup completed successfully!"

### Setting the environment

If you ran the setup script with a virtual environment name you need to activate the virtual environment before running the CertToolkit script. The syntax for that is:
```
source <virtual_env_name>/bin/activate
```

**Example:** If the virtual environment is called "env", you can activate the environment with the following command: 
```
source env/bin/activate
```

### The configuration file (defaults.yaml)

The `defaults.yaml` contains values needed by all the scripts in the Toolkit. All the customization required can be done by modifying the settings in this file. This file uses YAML syntax. It's not overly complicated but if something is not clear, please refer to the [YAML documentation](http://www.yaml.org/start.html). 

#### Passwords in the configuration file

The toolkit does *not* require any passwords to be hard-coded in the `defaults.yaml` file. It will prompt the user for the required passwords at runtime. This is the mode of operation that we recommend to avoid adding sensitive information in the configuration file.

In some cases, e.g. automation batch scripts, it's handy to allow for passwords in the configuration file so that the toolkit can run without user interaction. To minimize the risk of exposing sensitive information the toolkit behaves in the following way:

   * If the permissions of the `defaults.yaml` file are different from __600__ the script will try to set the permission to __600__ and will proceed only if it succeeds. This will prevent other users from having access to the file's contents.
   * Upon successful completion of the toolkit execution it will update the configuration file to remove the value configured for the parameters listed below:
      - __CM_PWD__ - CM admin password
      - __KS_PWD__ - keystore password
      - __TS_PWD__ - truststore password
      - __LOCAL_CA_KEY_PWD__ - password to protect the CA's key (only if self-signing certificates locally)
   * The feature above allows passwords in the configuration file to be used only once. The command line option `--keep-passwords` overrides this behaviour, preventing the removal of the passwords from the configuration file. 

#### Password characters

As usual, it's advised that strong different passwords be chosen for keystores and truststores. Alphanumeric characters can be used for these passwords with the following exceptions:

* Quotes are not allowed, due to [https://github.com/Supervisor/supervisor/issues/328](https://github.com/Supervisor/supervisor/issues/328).

#### SSL/TLS certificates requirements

When certificates are issues by Certificate Authorities (CAs), the use of the certificates can be restricted by the CA by setting "X509v3 Extended Key Usage" attributes in the certificates. If the CA doesn't do this and the certificate doesn't have the "X509v3 Extended Key Usage" section, it can be used for any purposes (Web Server authentication, Web Client authentication, etc.) If it does have that section the usage is limited to the flags specified in there.

The certificates used for enabling SSL/TLS for CDH must either have all the required attributes for the intended purposes (see below), or do not contain the "X509v3 Extended Key Usage" section, so it can be used without restrictions.

Depending on the SSL/TLS level you are planning to enable CDH you'll need to have the following attributes specified in the certificates you use:
* __TLS Web Server Authentication__ - This attribute is required for enabling SSL/TLS for the Cloudera Manager console and set TLS Levels 1 or 2.
* __TLS Web Client Authentication__ - If you're planning to enable TLS Level 3, the Cloudera Manager agents (SSL clients) must authenticate with the CM server using their certificates, and this attribute is required.

Also consider the following guidelines:
* Ensure the signature algorithm used for the certificate is **sha256WithRSAEncryption** (SHA-256)
 - SHA-1 is deprecated and should not be used
 - By default some Windows 2008R2 AD CA templates use the signature algorithm **rssssaPss**. This algorithm does *NOT* work with Hadoop.
* The certificates must NOT use wildcards. Each cluster node must have its own certificate.
* We recommend that the certificates must be signed by a proper CA (do NOT issue self-signed certificates).
* The CN component of the certificate's Subject must be the FQDN of the host for which the certificate is created. If the host has multiple network interfaces the CN must have the FQDN of the private interface.
* Additional names for the certificate/host can be added to the certificate as Subject Alternate Names (SANs). It's good practice to add the FQDN used for the CN as a "DNS" SAN entry as well. If you're planning to use a load balance for services like Impala, Hue, etc., the FQDN for the load balancer must be included as a "DNS" SAN entry in the certificate for the hosts that provide that services. For example, if you have a LB called impala.domain.com, the certificates for all the hosts that run an Impala Daemon should include the SAN DNS:impala.domain.com.
* The minimum for the **X509v3 Key Usage: critical** section must be:
 - Digital Signature
 - Key Encipherment

##### About signing certificates with Active Directory's "Web Server" template

The Active Directory Certificate Authority (ADCA) comes with predefined templates for signing certificates. The one typically used to sign certificates for Web Server use is the one called "Web Server". This template will create signed certificates that contain the "_TLS Web **Server** Authentication_" attribute but lack the "_TLS Web **Client** Authentication_" one.

Enabling TLS Level 3 with these certificates will fail due to the reason explained above. To solve this problem, we recommend that the ADCA administrator create a new template by cloning the existing "Web Server" template and add the missing attribute to it. Then use this new template to sign the certificates. If the toolkit is being used to sign the certificates using ADCA, the name of the new template can be configured using the `AD_CERT_TEMPLATE` property.

For a _non-optimal_ workaround, please see the description of the `ADD_SERVER_CERTS_TO_TRUSTSTORE` property below.

#### Commonly changed settings

These settings in this section are likely to be different for each CDH cluster. We recommend to review them carefully and update the file to reflect your environment.

The individual settings are explained below:

* __JAVA_HOME__ -  Location of Oracle JDK used by CM. Must be present and the same on all hosts.
<br>*Example*: `JAVA_HOME: /usr/java/jdk1.7.0_67-cloudera`

* __CM_USER__ - CM user name (must be in the Full Administrator role)
<br>*Example*: `CM_USER: admin`

* __CM_HOST__ - Fully qualified domain name of the CM host
<br>*Example*: `CM_HOST: host-1.example.com`

* __CM_PORT__ - HTTP port used by CM (unlikely to require changing)
<br>*Example*: `CM_PORT: 7180`

* __CM_SECURE_PORT__ - HTTPS port used by CM (unlikely to require changing)
<br>*Example*: `CM_SECURE_PORT: 7183`

* __CERT_DN_SUFFIX__ - Subject line DN suffix to be used in the generation of certificates for each one of the target hosts.
<br>*Example*: `CERT_DN_SUFFIX: "OU=BigData, O=Example, L=San Francisco, S=California, C=US"`

* __CERT_EMAIL__ - Email address to be added as a contact to the certificate requests. The email address is added as a SubjectAlternateName (SAN) item, as per RFC 3850's recommendation.
<br>*Example*: `CERT_EMAIL: webadmin@example.com`

* __TLS_LEVEL__ - TLS level to configure in Cloudera Manager. Valid values are: 0, 1, 2 and 3
<br>*Example*: `TLS_LEVEL: 3`

* __HDFS_YARN_SSL, HIVE_SSL, HBASE_SSL, NAVIGATOR_SSL, HUE_SSL, IMPALA_SSL, OOZIE_SSL, SOLR_SSL, KTS_SSL, KMS_SSL__ - Each one of these properties indicate whether SSL should be enabled or not for the indicated service. If a component has a value of `YES` but is not installed in the cluster it will be ignored. Valid values: `YES` or `NO`
<br>*Example*:
   ```
   HDFS_SSL: YES
   YARN_SSL: YES
   HIVE_SSL: YES
   HBASE_SSL: YES
   NAVIGATOR_METADATA_SSL: YES
   HUE_SSL: YES
   IMPALA_SSL: YES
   OOZIE_SSL: YES
   SOLR_SSL: YES
   KTS_SSL: YES
   KMS_SSL: YES
   ```

* __ENABLE_WEB_CONSOLE_AUTH__ - Enable Web Console authentication for HDFS and YARN. Valid values: `YES` or `NO`
<br>*Example*: `ENABLE_WEB_CONSOLE_AUTH: YES`

* __AD_CA_URL__ - Base URL for the Active Directory CA page used to sign CSRs. Only needed when using AD CA automation for signing requests.
<br>*Example*: `AD_CA_URL: "http://w2k8-2.ad.sec.cloudera.com/certsrv"`

* __AD_CERT_TEMPLATE__ - AD certificate template to be used to sign the certificates.
<br>*Example*: `AD_CERT_TEMPLATE: WebServer`

#### Other settings (think twice before changing these)

The remaining settings in the `defaults.yaml` file, described in this section, are usually the same across different environment and usually don't require changing. We recommend that the default values for these settings be used.

* __SEC_BASE__ - Define the base path for location where the toolkit will deploy the security files on *all* hosts.
<br>*Example*: `SEC_BASE: /opt/cloudera/security`

* __WAREHOUSE_BASE__ - Define the location where the toolkit will stage files and tools before deploying them to the cluster hosts.
<br>*Example*: `WAREHOUSE_BASE: /opt/cloudera/security/setup`

* __WAREHOUSE_BACKUP__ - Define the location that the toolkit will use to backup the security warehouse files.
<br>*Example*: `WAREHOUSE_BACKUP: /opt/cloudera/security_setup_backup`

* __OPENLDAP_CERTS__ - OpenLDAP certificates location.
<br>*Example*: `OPENLDAP_CACERTS: /etc/openldap/cacerts`

* __AGENT_PWDFILE__ - Agent password file to be created in the target hosts
<br>*Example*: `AGENT_PWDFILE: /etc/cloudera-scm-agent/agentkey.pw`

* __CMD_WAIT_TIME_SEC__ - Time, in seconds, that the toolkit waits between checks for the completion of commands executing in Cloudera Manager.
<br>*Example*: `CMD_WAIT_TIME_SEC: 5`

* __CMD_WAIT_FEEDBACK__ - Number of completion checks that the toolkit executes before showing a progress feedback message on screen.
<br>*Example*: `CMD_WAIT_FEEDBACK: 4`

* __PARALLEL_WAIT_TIME_SEC__ - Time, in seconds, that the toolkit waits between checks for the completion of commands that are executed in parallel. These commands are typically much faster and we use a shorter wait time. Progress feedback messages are shown for all checks of parallel executions.
<br>*Example*: `PARALLEL_WAIT_TIME_SEC: 2`

* __CM_PWD__ - Password for the CM user. This is not required, since the toolkit will prompt the user for the password at run time. We recommend to avoid adding passwords to the configuration file. 
<br>*Example*: `CM_PWD: admin`

* __KS_PWD__ - Password to protect the Java keystores. This is not required, since the toolkit will prompt the user for the password at run time. We recommend to avoid adding passwords to the configuration file.
<br>*Example*: `KS_PWD: mysecurepassword`

* __TS_PWD__ - Password to protect the truststore. This is not required, since the toolkit will prompt the user for the password at run time. We recommend to avoid adding passwords to the configuration file.
<br>*Example*: `TS_PWD: mysecurepassword`

* __KEY_SIZE__ - Size of the keys created for SSL encryption
<br>*Example*: `KEY_SIZE: 2048`

* __LOCAL_CA_SUBJ_DN__ - Subject for the __local__ Certificate Authority (CA). This  settings is only needed when creating your own local CA to self-sign certificates (__*NOT*__ recommended for production use)
<br>*Example*: `CA_SUBJ_DN: "C=US, ST=California, L=San Francisco, O=Example, OU=BigData, CN=Admin"`

* __LOCAL_CA_KEY_PWD__ - Password for the __local__ CA certificate key. This  settings is only needed when creating your own local CA to self-sign certificates (__*NOT*__ recommended for production use). This is not required, since the toolkit will prompt the user for the password at run time. We recommend to avoid adding passwords to the configuration file.
<br>*Example*: `LOCAL_CA_KEY_PWD: mycapassword`

* __LOCAL_CA_KEY_SIZE__ - __Local__ CA key size. This  settings is only needed when creating your own local CA to self-sign certificates (__*NOT*__ recommended for production use)
<br>*Example*: `LOCAL_CA_KEY_SIZE: 2048`

* __LOCAL_CA_EMAIL__ - Email to be associated with the local CA certificate.
<br>*Example*: `LOCAL_CA_EMAIL: no-reply@example.com`

* __KTS_SSL_DIR__ - Directory used by the Key Trustee Server to store its SSL certificates.
<br>*Example*: `KTS_SSL_DIR: /var/lib/keytrustee/.keytrustee/.ssl`

* __CERT_ALT_DOMAIN_NAMES__ - Alternate domain names to be used for SAN certificates (comma separated list of domain names). An additional SAN entry will be specified for each host, for each domain in the list. The additional SAN entry in the certificate will have the form: `DNS:<host>.<alt_domain>`.
<br>*Example*: `CERT_ALT_DOMAIN_NAMES: example.com,corp.example.com`

* __CERT_ALT_NAMES_FILE__ - File containing SAN entries for specific hosts. One line per host with each line having the following format (the host name and the list of SAN entries are separated by a space):
  ```
  host_SHORT_name comma_separated_list_of_san_entries
  ```
Each SAN in the list must be either one of these forms: `DNS:fqdn` or `IP:ip_address`.
<br>*Example*: `CERT_ALT_NAMES_FILE: /home/webadmin/alt_names.txt`
<br>*Example of the alternate name file contents*:
  ```
  host-1 DNS:cloudera-manager.example.com,IP:10.12.13.14
  ```

* __ADD_SERVER_CERTS_TO_TRUSTSTORE__ - Indicates whether server certificates should be added to the truststore or not. We highly recommended that the default value (`NO`) is used. The only situation where it may be necessary to add server certificates to the truststore is when the certificates don't have the extended key usage attribute "_TLS Web Client Authentication_", which causes the TLS Level 3 configuration to fail. In these cases, this configuration property can be set to `YES` as a workaround.
<br>*Example*: `ADD_SERVER_CERTS_TO_TRUSTSTORE: YES`

### Checking connectivity to all nodes

Before using the toolkit to secure Cloudera Manager and the associated CDH clusters, it's good practice to ensure that the connectivity and credentials to connect to all the hosts are ok. To do that, run the following command to execute the connectivity pre-check:

```
python certtoolkit.py precheck
```

If the command completes without errors, the connectivity and credentials for all the hosts are ok and you can proceed with the next steps. Otherwise, troubleshoot and fix the issues before continuing.

If one or more nodes of the cluster are temporarily inaccessible, they can be *blacklisted* with the command `--host-blacklist`.

### Securing the cluster

Once the `defaults.yaml` has been reviewed and configured correctly, you're ready to turn on SSL/TLS encryption for your cluster. This can be done by following this 3-step process:

1. __Prepare CSRs for cluster nodes__
   Every node in the cluster will need a separate certificate for enabling SSL/TLS for the services running on it. At the time of this writing the use of SAN (SubjectAlternateNames) certificates is not supported.
   <p>The `prepare` action of the toolkit will generate Certificate Signing Request (CSRs) for all the nodes that still don't have a certificate (or CSR). The generated CSRs will be stored under `<SEC_BASE>/setup/certs`.
   <p>To create CSRs for all the nodes, run the following command:
   ```
   python certtoolkit.py prepare
   ```

2. __Get the signed certificates__
   The next step is to get the CSRs generated by the toolkit and get them signed by a Certificate Authority (CA). The CA does **not** need to be a public well-known CA. If the company has an internal PKI infrastructure, one of their internal CAs can be used for signing the cluster certificates. Active Directory, for example, is a commonly used CA.
   <p>There are a few possible ways to get the CSRs signed:
      1. __Manually__
        In certain cases, the automation provided by this toolkit cannot be used for assisting with signing the CSRs. In those cases, copy all the new CSRs from the `<SEC_BASE>/setup/certs` directory and provide them to the CA organization or person who'll be in charge of organizing the certificate signing.
        <p>Once you receive the signed certificates, copy the files to the same directory as the CSRs were originally (`<SEC_BASE>/setup/certs`). The following requirements must be met:
           * The signed certificates must be provided in **PEM format with base-64 encoding**.
           * The CSRs and the signed certificates files must cohexist in this same directory.
           * The signed certificates must have the same name as the associated CSR file, with a `.pem` extension instead of `.csr`.
           * The CSR and the signed certificate files must be named after the host's short name.

        For example:
        ```
        /opt/cloudera/security
        ├── setup
        │   ├── certs
        │   │   ├── host-cdh55-1.csr
        │   │   ├── host-cdh55-1.pem
        │   │   ├── host-cdh55-2.csr
        │   │   ├── host-cdh55-2.pem
        │   │   ├── host-cdh55-3.csr
        │   │   ├── host-cdh55-3.pem
        │   │   ├── host-cdh55-4.csr
        │   │   └── host-cdh55-4.pem
        ```

     
        It's also necessary to get a copy of the certificates for the CAs that were used to sign the CSRs. These certificates should be copied to the directory `<SEC_BASE>/setup/ca-certs`.
         The following requirements must be met for the CA certificates:
           * The CA certificates must be provided in **PEM format with base-64 encoding**.
           * If the CSRs were signed by an _intermediate_ CA, you must get the certificates for _both_ the intermediate and root CAs, saved in separate files.
           * The base name for the CA certificate file(s) is arbitrary, and you can choose the name to better identify each one.
           * The CA certificates must have the extension `.pem`.

        For example:
        ```
        /opt/cloudera/security
        ├── setup
        │   ├── ca-certs
        │   │   ├── ad-W2K8-1-CA.pem
        │   │   └── ad-W2K8-2-CA.pem
        ```

      2. __Use the toolkit to get the CSRs signed by Active Directory__
         The toolkit can be used to automate the signing of CSRs by Active Directory. The ability to use this feature is dependent on how the Active Directory (AD) CA is configured.
         <p>In some deployments, the AD CA is configured to enforce separation of duties in certificate management. This means that the user that submits a CSR for signing is not able to complete the signing process. Another user, usually a CA administrator, has to approve that request and get it signed, so that the original use can then download the signed request.
         <p>The toolkit does not support automation in such configuration. To be able to use the toolkit for signing CSRs with AD it's required that a single administrator user be able to submit, sign and download certificates.
         <p>If this requirement is satisfied, the command below will sign all the CSRs that were created in the preparation step above and were not yet signed:
         ```
         python certtoolkit.py sign_certs --ca-type=ad
         ```
         The user will be prompted for the credentials of the AD user with privileges to generate the signed certificates. The user name **must** be provided in the form `<DOMAIN>\<username>`.

      3. __Use the toolkit to create a local self-siged CA and issue the necessary certificates__

         **This option is very insecure and only recommended for tests**. _Do not use this in customers' environments._
         <p>Using this option the toolkit will create new Certificate Authority credentials (a private key and self-signed certificate) and will use it to sign all the other cluster certificates. The CA credentials are stored in the security warehouse used by the toolkit.
         <p>The following command will sign certificates with a locally created CA:
         ```
         python certtoolkit.py sign_certs --ca-type=local
         ```


3. __Enable TLS for CM and CDH clusters__
   Once the certificates for all the hosts have been signed, using any of the methods explained above, it's time to configure CM and cluster services to enable SSL/TLS encryption.
   <p>The toolkit takes care of the following tasks:
     * Distribute certificates and keys to a standard location on all the cluster nodes
     * Configures Cloudera Manager and CDH services, through CM API, to enable TLS encryption, setting all the required properties.
     * Restart the Cloudera Manager server
     * Restart the Cloudera Manager agent on all nodes
     * Restart the CDH clusters, if SSL/TLS for CDH services has been marked to be enabled in the configuration file.

    The following command executes all the steps above:
    ```
    python certtoolkit.py enable_tls
    ```

### Unsecuring a cluster
Sometimes it may be necessary to disable SSL/TLS encryption for a cluster. To unsecure a previously secured cluster, run the following command:
```
python certtoolkit.py disable_tls
```

This command will undo the CM and CDH services configuration using CM API and restart the needed components. It will *not* remove certificate files from the cluster nodes.

### Adding new hosts to the cluster
When adding new nodes to a secured cluster, it's necessary to configure SSL/TLS for the new nodes before they can communicate with Cloudera Manager. When secured, Cloudera Manager can only communicate over TLS and the new nodes won't be able to send heartbeats until they have certificates and the agents have the correct configuration in place.

Thus, we need a way to get the new nodes bootstrapped to a point where they can do basic heartbeat communication with Cloudera Manager. Once that's done, the remaining administrative tasks (adding nodes to cluster, deploying roles, etc.) can be done through the Cloudera Manager console.

#### Prerequisites
The toolkit helps with this initial configuration. There are some pre-requisites, though, that must be done manually by the system administrator beforehand:

   * [Install the Oracle JDK](http://tiny.cloudera.com/install-path-b). __The version installed must match the version already being used__ by the existing secured nodes and must be in the exact same location.
   * [Install Cloudera Manager Agent](http://tiny.cloudera.com/install-path-b) __The agent version installed must match the version already being used__ by the existing cluster nodes.
   * *If the cluster is Kerberized*, which is very likely and recommended, [install the Kerberos prerequisites](http://tiny.cloudera.com/kerberos_wizard)

#### Adding nodes
Once the tasks above are completed, the process to secure and add new hosts to Cloudera Manager is very similar to the process to secure the cluster, described above.

1. Create a text file containing the FQDN for all the new hosts to be added to the cluster (one host per line). For example:

   ```
   $ cat new_hosts.txt
   host-10.example.com
   host-11.example.com
   host-12.example.com
   ```
2. Generate CSRs for those hosts with the following command:

   ```
   python certtoolkit.py prepare --new-hosts=new_hosts.txt
   ```
3. Get the new CSRs signed by one of the 3 methods explained in the [Securing the Cluster](#securing-the-cluster) section above.  Note it is not necessary to add the ```--new-hosts=new_hosts.txt``` with this step, as the script will recognize hosts already issued certificates with the message ```(already exists; skipped)```
4. Configure and enable TLS for the new hosts' agents with the following command:

   ```
   python certtoolkit.py enable_tls --new-hosts=new_hosts.txt
   ```

### Additional command line options

The following command line options can be used to modify the behaviour of the toolkit:

* __--help__ - show a summary of command line options
* __--config-file=PATH__ - Path of the YAML configuration file. Default: defaults.yaml

  By default the toolkit will look for the configuration file on the same directory where the `certtoolkit.py` script is located, with the name of `defaults.yaml`. If the configuration file is located elsewhere, you can specify its location using this option.
* __--parallelism=NUM__ - Number of hosts that will be updated in parallel.Default: 10

  Actions that need to be run remotely on the cluster nodes are executed in parallel by the toolkit. This option can be used to change the number of nodes that are updated in parallel. 
* __--new-hosts=FILE_PATH__ - File with the list of FQDN of the hosts to be added to the cluster (one per line).

  See the section [Adding new hosts to the cluster](#adding-new-hosts-to-the-cluster) above.
* __--host-blacklist=FILE_PATH__ - File with the list of FQDN of the hosts to be ignored (one per line). This parameter is required when enabling TLS for Cloudera Manager instances that have *inaccessible* registered hosts. The *inaccessible* hosts need to be blacklisted so that the toolkit execution can succeed.

  __IMPORTANT__: If certificate changes are made while some hosts are inacessible, those hosts' truststores and keystores may have to be updated when the hosts are ready to re-join the cluster (the `--new-hosts` option can be used for that).
* __--no-restart__ - Do not restart CM or CDH services

  The `enable_tls` and `disable_tls` actions will, by default, restart the required services to ensure that the configuration changes take effect. When using this option, the configuration changes will be made but no services will be restarted, leaving up to the user to perform the restarts manually at a later stage. 
* __--private-key-file=PK_FILE__ - SSH private key file

  By default, when executing the `enable_tls` and `disable_tls` actions, the toolkit will prompt the user for the SSH password to connect to other cluster nodes. This password cannot be specified in the configuration file and must always be entered interactively. Using this option, the user can specify a SSH private key file to authenticate the SSH connection instead, and avoid the password prompt. Note that the user's public key must be added to the user's `authorized_keys` file on the remote hosts, in advance.
* __--keep-passwords__ - Keep passwords in defaults.yaml file. If this option is not specified, passwords will be removed from the configuration file.

  See the section [Passwords in the configuration file](#passwords-in-the-configuration-file) above.

### Security warehouse backup

During the TLS/SSL configuration the toolkit creates a "security warehouse" directory to serve as a staging location for certificates, keys, etc. The location of the security warehouse is `${SEC_BASE}/setup`.

When the toolkit's `prepare` action is executed, two backups of the security warehouse are taken. The aim of these backups is to ensure that certificates and keys can be retrieved in case something goes wrongs during the toolkit's execution. The location of the backup directory used by the toolkit is `${SEC_BASE}_setup_backup`.

For example, if the SEC_BASE setting is configured as `/opt/cloudera/security` (default), the security warehouse directory will be `/opt/cloudera/security/setup`, while the backup directory will be at `/opt/cloudera/security_setup_backup`. The backup directory is placed outside SEC_BASE to avoid the backups being lost in case SEC_BASE is deleted accidentally.

### Structure of the Security repository

All the files and directories handled by the toolkit are found under the directory defined by the `SEC_BASE` property, which by default is `/opt/cloudera/security`.

All the certificates and other files that need to be distributed across the cluster nodes are staged locally in the toolkit's Security Warehouse (`${SEC_BASE}/setup`) and later copied to their respective nodes during the execution of the `enable_tls` action.

The toolkit's `prepare` action will create the Security Warehouse directory structure and generate the CSRs for all the existing cluster nodes. It also saves in the warehouse the keystores and keys associated which the CSRs.

```
/opt/cloudera/security
└── setup
    ├── ca-certs
    ├── certs
    │   ├── host-cdh55-1.csr
    │   ├── host-cdh55-2.csr
    │   ├── host-cdh55-3.csr
    │   └── host-cdh55-4.csr
    ├── jks
    │   ├── host-cdh55-1-keystore.jks
    │   ├── host-cdh55-2-keystore.jks
    │   ├── host-cdh55-3-keystore.jks
    │   └── host-cdh55-4-keystore.jks
    ├── tmp
    ├── truststore
    └── x509
        ├── host-cdh55-1-unsignedkey.pem
        ├── host-cdh55-2-unsignedkey.pem
        ├── host-cdh55-3-unsignedkey.pem
        └── host-cdh55-4-unsignedkey.pem
```

The `prepare` action also takes two backups of the `SEC_BASE` directory: one before it's execution and one after. The aim of the "BEFORE" backup is to safe-guard existing files within `SEC_BASE` from any toolkit malfunction that could innadvertently remove files. The "AFTER" backup ensures that newly created host keys and keystores are backed up immediately after they are generated. These backup files are stored under `${SEC_BASE}_setup_backup` and can be used to restore the Security Warehouse in case of accidents.

```
/opt/cloudera/security_setup_backup
├── setup_AFTER_PREPARE_20160106120618.tar.gz
└── setup_BEFORE_PREPARE_20160106120608.tar.gz
```

After the certificates are signed (either manually or through the `sign_certs` action), the signed certificates for the hosts __and__ CAs are added to the security warehouse:

_Note: the listing below only shows the files added to the warehouse during the certificate signing step_
```
/opt/cloudera/security
└── setup
    ├── ca-certs
    │   ├── ad-W2K8-1-CA.pem
    │   └── ad-W2K8-2-CA.pem
    ├── certs
    │   ├── host-cdh55-1.pem
    │   ├── host-cdh55-2.pem
    │   ├── host-cdh55-3.pem
    │   └── host-cdh55-4.pem
```

The `enable_tls` action will create the remaining required files in the security warehouse, prior to distributing contents to the cluster nodes. These files include the different required truststores and the X509 keys and certificates.

_Note: the listing below only shows the files added to the warehouse during the `enable_tls` step_
```
/opt/cloudera/security
├── setup
│   ├── jks
│   │   └── truststore.jks
│   ├── truststore
│   │   └── ca-truststore.pem
│   └── x509
│       ├── host-cdh55-1-cert.pem
│       ├── host-cdh55-1-keynopw.pem
│       ├── host-cdh55-1-key.pem
│       ├── host-cdh55-1-unsignedkey.pem
│       ├── host-cdh55-2-cert.pem
│       ├── host-cdh55-2-keynopw.pem
│       ├── host-cdh55-2-key.pem
│       ├── host-cdh55-2-unsignedkey.pem
│       ├── host-cdh55-3-cert.pem
│       ├── host-cdh55-3-keynopw.pem
│       ├── host-cdh55-3-key.pem
│       ├── host-cdh55-3-unsignedkey.pem
│       ├── host-cdh55-4-cert.pem
│       ├── host-cdh55-4-keynopw.pem
│       ├── host-cdh55-4-key.pem
│       └── host-cdh55-4-unsignedkey.pem
```

The `enable_tls` action recreates the `truststore.jks` from scratch every time it's run. The previous truststore is backed up before that, just in case...

_Note: the listing below only shows the files added to the warehouse backup directory during the `enable_tls` step_
```
/opt/cloudera/security_setup_backup
└── truststore.jks.20160106135517
```

After all the required files have been created in the Security Warehouse, the `enable_tls` action copies the files to their final locations on all the nodes, also creating symbolic links as needed. The example below shows the final deployment contents for a single node. Other nodes will have a similar content, with only file name differences.

_Note: the listing below only shows the files added to the Security base directory during the deployment phase of the `enable_tls` step_
```
/opt/cloudera/security
├── ca-certs
│   ├── 082ba6df.0 -> ad-W2K8-2-CA.pem
│   ├── 4507f087.0 -> ad-W2K8-1-CA.pem
│   ├── ad-W2K8-1-CA.pem
│   └── ad-W2K8-2-CA.pem
├── jks
│   ├── keystore.jks -> /opt/cloudera/security/jks/host-cdh55-1-keystore.jks
│   ├── host-cdh55-1-keystore.jks
│   └── truststore.jks
├── truststore
│   └── ca-truststore.pem
└── x509
    ├── cert.pem -> /opt/cloudera/security/x509/host-cdh55-1-cert.pem
    ├── keynopw.pem -> /opt/cloudera/security/x509/host-cdh55-1-keynopw.pem
    ├── key.pem -> /opt/cloudera/security/x509/host-cdh55-1-key.pem
    ├── host-cdh55-1-cert.pem
    ├── host-cdh55-1-keynopw.pem
    └── host-cdh55-1-key.pem
```

The name of the symbolic links above are identical across all the nodes. These are the names used in the configuration of Cloudera Manager and other CDH components.

### Known issues

* The toolkit shows a warning for KTS clusters saying that Kerberos is not enabled, even when Kerberos is enabled for the CDH cluster in the same Cloudera Manager deployment.

   This is not necessarily a bug and can be ignored. Even though some Kerberos configuration properties are associated with the Cloudera Manager deployment (e.g. KDC type, Kerberos admin credentials, etc.), the actual enablement of Kerberos authentication is service-specific. Thus, the toolkit check for Kerberos being enabled is currently associated with the HDFS service in each cluster. If the cluster does not have a HDFS service the toolkit will show the warning, but it can be ignored.

* When the toolkit is used for setting up in-flight encryption for HDFS, it will enable Data Transfer Encryption for that service, even if HDFS at-rest encryption is in use. This scenario can cause data to be doubly encrypted, since data encrypted at-rest is sent in the encrypted form over the network and decrypted at the client side. The additional encryption cycle adds some performance degradation and you may want to disable it, if not necessary.
