Installation:
===============
1. Copy file ids.conf to /etc/zabbix/zabbix_agentd.d
2. Copy files ids.dbspace and ids.stat to /etc/zabbix/scripts/
3. Add sudo permissions:
zabbix          ALL=(informix) NOPASSWD: /etc/zabbix/scripts/ids.*
4. Create file  /etc/zabbix/scripts/ids.stat with IDS environmets 
5. Restart zabbix-agent

Template_DB_Informix.xml - template for zabbix server.

---------------------------------------------------------------------------------------------------------------------
Files:
# ls -al /etc/zabbix/scripts/ids.* /etc/zabbix/zabbix_agentd.d/ids.conf
-rwxr--r--    1 informix informix       4934 Jul 17 2018  /etc/zabbix/scripts/ids.dbspace
lrwxrwxrwx    1 root     system           20 Jun 13 2018  /etc/zabbix/scripts/ids.env -> /etc/informix/server
-rwxr-xr-x    1 informix informix      24696 Jan 30 2019  /etc/zabbix/scripts/ids.stat
-rw-r--r--    1 root     system         1517 Jun 13 2018  /etc/zabbix/zabbix_agentd.d/ids.conf

ids.env - my profile with Informix environmets
---------------------------------------------------------------------------------------------------------------------


History:
2019-01-30 - First release.

2020-02-07 - Added network statistics. Description ids.stat network JSON in readme.network.json.
    added to ids.conf:
    # IDS network
    UserParameter=ids.network,/usr/bin/sudo -u informix /etc/zabbix/scripts/ids.stat network
