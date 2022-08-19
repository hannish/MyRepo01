# Author  : Manu T N (manu.tn@oracle.com)
# Version : 01.00  02/18/2020 - Initial version

import sys
import os
import re
import string


# Load the properties from the properties file.
from java.io import FileInputStream


    
def serversRunningStatus():
    domainConfig()
    serverList=cmo.getServers()
    domainRuntime()
    cd('/ServerLifeCycleRuntimes/')
    print ("[Weblogic_Server_Status]")
    output_File.write ("[Weblogic_Server_Status]\n")
    for server in serverList:
        name = server.getName()
        cd (name)
        serverState=cmo.getState()
        print ("ServerStatus-"+name +'='+serverState)
        output_File.write ("ServerStatus-"+name +'='+serverState+"\n")
        cd ('..')
    print ("\n" * 2)
    output_File.write ("\n" * 2)

def testDataSource():
    #domainRuntime()
    allServers=domainRuntimeService.getServerRuntimes()
    if (len(allServers) > 0):
        print ("[Datasource_Connection]")
        output_File.write ("[Datasource_Connection]\n")
        for tempServer in allServers:
            jdbcServiceRT = tempServer.getJDBCServiceRuntime()
            dataSources = jdbcServiceRT.getJDBCDataSourceRuntimeMBeans()
            for dataSource in dataSources:
                testPool = dataSource.testPool()
                dataSourceName = dataSource.getName()
                dataSourceNamePad=dataSourceName[:30]
                if (testPool == None):
                    print ("TestDatasource-"+dataSourceNamePad+'<->'+tempServer.getName()+"="+'OK')
                    output_File.write ("TestDatasource-"+dataSourceNamePad+'<->'+tempServer.getName()+"="+'OK'"\n")
                else:
                    print ("TestDatasource-"+dataSourceNamePad+'<->'+tempServer.getName()+"="+'FAILURE')
                    output_File.write ("TestDatasource-"+dataSourceNamePad+'<->'+tempServer.getName()+"="+'FAILURE'"\n")
        print ("\n" * 2)
    output_File.write ("\n" * 2)

def datasourceType():
    serverConfig()
    print ("[Type_Of_Datasource]")
    output_File.write ("[Type_Of_Datasource]\n")
    allJDBCResources = cmo.getJDBCSystemResources()
    for jdbcResource in allJDBCResources:
        dsname = jdbcResource.getName()
        cd('/JDBCSystemResources/' +dsname+ '/JDBCResource/' +dsname+ '/JDBCOracleParams/' +dsname)
        dsType = str(get('FanEnabled'))
        if dsType == '0':
            print ("DatasourceType-"+dsname+"="+"GENERIC")
            output_File.write ("DatasourceType-"+dsname+"="+"GENERIC""\n")
        else:
            print ("DatasourceType-"+dsname+"="+"GRIDLINK")
            output_File ("DatasourceType-"+dsname+"="+"GRIDLINK""\n")
    print ("\n" * 2)
    output_File.write ("\n" * 2)

def activeConnections():
    domainRuntime()
    allServers=domainRuntimeService.getServerRuntimes()
    print ("[Active_Datasource_Connections]")
    output_File.write ("[Active_Datasource_Connections]\n")
    for tempServer in allServers:
        jdbcServiceRT = tempServer.getJDBCServiceRuntime()
        dataSources = jdbcServiceRT.getJDBCDataSourceRuntimeMBeans()
        for dataSource in dataSources:
            print ("ActiveConnections-"+dataSource.getName()+'<->'+tempServer.getName()+"="+str(dataSource.getActiveConnectionsCurrentCount()))
            output_File.write ("ActiveConnections-"+dataSource.getName()+'<->'+tempServer.getName()+"="+str(dataSource.getActiveConnectionsCurrentCount())+str("\n"))
    print ("\n" * 2)
    output_File.write ("\n" * 2)


def appStatus():
    print ("[Deployment_Status]")
    output_File.write ("[Deployment_Status]\n")
    domainConfig()
    cd ('/AppDeployments')
    apps=cmo.getAppDeployments()
    for i in apps:
        redirect('nul','false')
        domainConfig()
        redirect('nul','true')
        cd ('/AppDeployments/'+i.getName()+'/Targets')
        redirect('nul','false')
        mytargets= ls(returnMap='true')
        redirect('nul','true')
        #print (mytargets)
        domainRuntime()
        cd('AppRuntimeStateRuntime/AppRuntimeStateRuntime')
        for targetinst in mytargets:
            curstate4=cmo.getCurrentState(i.getName(),targetinst)
            print ("AppStatus-"+i.getName()+"["+targetinst+"]"+"="+curstate4)
            output_File.write ("AppStatus-"+i.getName()+"["+targetinst+"]"+"="+curstate4+"\n")
    print ("\n" * 2)
    output_File.write ("\n" * 2)

def deploymentHealth():
        #print ("[Application_Health]")
        #output_File.write ("[Application_Health]\n")
        #output_File3.write ("[Application_Health]\n")
        domainRuntime()
        cd('/ServerRuntimes')
        redirect('NUL','false')
        serverList=ls(returnMap='true')
        redirect('NUL','true')
        for server in serverList:
                cd('/ServerRuntimes')
                cd(server)
                cd('ApplicationRuntimes')
                redirect('NUL','false')
                applist=ls(returnMap='true')
                redirect('NUL','true')
                for app in applist:
                         cd(app)
                         healthstate=get('HealthState')
                         #health = healthstate.split(",")[2]
                         #print health
                         #print(('AppHealth-' + app + '[' + server + ']'+'=' + str(healthstate)))
                         #output_File.write(('AppHealth-' + app + '[' + server + ']'+'=' + str(healthstate) + "\n"))
                         output_File3.write(('AppHealth-' + app + '[' + server + ']'+'=' + str(healthstate) + "\n"))
                         cd('..')
        print ("\n" * 2)
        output_File.write ("\n" * 2)


#Main

#OutputFiles
outputFile = r"E:\\scripts\\validator\\logs\\output_wlst.ini"
tempAppHealthFile = r"E:\\scripts\\validator\\logs\\appHealth.txt"
#pwd_file = r"E:\\scripts\\validator\\logs\\pwd.txt"


open(outputFile, 'w').close()
open(tempAppHealthFile, 'w').close()
#open(pwd_file, 'w').close()

output_File = open(outputFile,"a+")
output_File3 = open(tempAppHealthFile,"a+")
#output_File4 = open(pwd_file, "w+")

#Get Weblogic Version
print "[Weblogic_Version]"
print "WeblogicVersion="+version
print ("\n" * 3)
output_File.write ("[Weblogic_Version]\n")
output_File.write ("WeblogicVersion="+version+"\n")
output_File.write ("\n" * 3)

#Main
#Variables related to retrive weblogic password
property_file = r"E:\\myMicros\\Oracle\\Middleware\\user_projects\\domains\\bifoundation_domain\\servers\\bi_server1\data\\nodemanager\\boot.properties"
domain_home = r"E:\\myMicros\\Oracle\\Middleware\\user_projects\\domains\\bifoundation_domain"
service = weblogic.security.internal.SerializedSystemIni.getEncryptionService(domain_home)
encryption = weblogic.security.internal.encryption.ClearOrEncryptedService(service)
str2 = ""
if os.path.isfile(property_file):
    boot_File1 = open(property_file,"r+")
    credentials = [line.rstrip('\n') for line in boot_File1]
    for i in credentials:
        if "password" in i:
            temp_weblogic_pass = re.findall('password=(.*)', i)
            Encryptd_weblogic_pass = str2.join(temp_weblogic_pass)
            new_pwd_str = Encryptd_weblogic_pass.replace("\\", "", 1)
            weblogic_pwd = encryption.decrypt(new_pwd_str)
            #print ("Weblogic server Admin password : %s" %weblogic_pwd)
            #output_File4.write (weblogic_pwd)
else:
    print("\n" * 2)
    print ("boot.properties does not exists under "+property_file)
    print ("Exiting.....")
    print("\n" * 2)
    exit()

#Connect to Weblogic Admin Server
#connect('weblogic', weblogic_pwd, 't3s://myhostname:7002')
#redirect('nul','false')
try:
    connect('weblogic', weblogic_pwd, 't3s://myhostname:7002')
    redirect('nul','false')
    print "ConnectToWeblogic=Success"
    output_File.write ("ConnectToWeblogic=Success"+"\n")
    print ("\n" * 3)
    output_File.write ("\n" * 3)
except WLSTException:
    print "ConnectToWeblogic=Failure"
    output_File.write ("ConnectToWeblogic=Failure"+"\n")
    print ("\n" * 3)
    output_File.write ("\n" * 3)
    exit()

cmgr = getConfigManager()
edit()
startEdit()
print ('[Active_WebLogic_Sessions]')
output_File.write ('[Active_WebLogic_Sessions]\n')
if cmgr.haveUnactivatedChanges():
    print ("Unactivatedchanges=PRESENT")
    output_File.write ("Unactivatedchanges=PRESENT\n")
    showChanges()
else:
    print ("Unactivatedchanges=NOT_PRESENT")
    output_File.write ("Unactivatedchanges=NOT_PRESENT\n")
cancelEdit('y')
print ("\n" * 3)
output_File.write ("\n" * 3)

#Check Server Status
serversRunningStatus()

#Check DataSource Connectivity
testDataSource()

#Get DataSource Type
#datasourceType()

#Active connections
#activeConnections()

#Status of the applications in domain
appStatus()

#Deployment Health 
deploymentHealth()


#Disconnect from the Admin Server
disconnect()

output_File.close()
output_File3.close()
#output_File4.close()

output_File = open(outputFile,"a+")
output_File3 = open(tempAppHealthFile,"r+")
#output_File4 = open(pwd_file,"w+")


#parsing the output of App Health Status
print ("[Application_Health]")
output_File.write("[Application_Health]"'\n')
for line in output_File3.readlines():
    line = re.sub("Component(.*?)State\\:","",line)
    line = re.sub("\\,MBean(.*?)ReasonCode\\:\\[\\]","",line)
    print (line.strip())
    output_File.write(line.strip()+'\n')

output_File.close()
output_File3.close()
os.remove(tempAppHealthFile)
