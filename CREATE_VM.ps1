#Use Mysql.Data
#DATE: 2017.11.24

Write-Host
"==================================================================
|                      自动创建虚拟机脚本v2.0                        |
|    若要使用文件导入虚拟机信息,请将vmlist.csv文件与此脚本放在同级目录     |
===================================================================
"

$FILEROOT = Split-Path -Parent $MyInvocation.MyCommand.Definition

[void][system.Reflection.Assembly]::LoadFrom("C:\\Program Files (x86)\\MySQL\MySQL Connector Net 6.10.4\\Assemblies\\v4.5.2\\MySql.Data.dll") #载入mysql驱动
$MysqlServer = "10.34.58.110"
$Database = "test" #数据库名
$MysqlUser = "sql10_34_58_110" #账户
$MysqlPassword="ZWWnS6BkQk" #密码
$connectionString = "server=$MysqlServer;uid=$MysqlUser;pwd=$MysqlPassword;database=$Database;charset=$charset;SslMode=None"
$connection = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionString)
$connection.Open()

$sqlquery = "select CONCAT(businesses,'_',ip,'_',system,'_',application) vmname,businesses,application,cpu,memory,disk,system,ip,mask,gateway,dns,net,type,hostname,vmhost,datastore,resourcepool,folder from test" #SQL语句
$req = New-Object Mysql.data.mysqlclient.mysqlcommand($sqlquery,$connection)
$dataAdapter = New-Object mysql.data.mysqlclient.mysqldataAdapter($req)
$dataset = New-Object system.data.dataset
$dataAdapter.fill($dataset,"query")|Out-Null
$dataset.tables["query"]|Export-Csv -Path $FILEROOT\sqlout.csv



function CDVC
{
$Vcenter = "10.34.62.6" #VCENTER地址
$VcUser = "administrator" #VC账号
$VcPassword = "jskj!OA2" #VC密码
$WINDOWS_TEMPLETE = "Template.windows2008.Welcome123" #windows模板
$LINUX_TEMPLETE = "Template.JS.CentOS_6.3.Mini_jskj#123" #linux模板
Add-PSSnapin -name *vmware* #POWERSHELL 单独运行时追加vmware命令
Connect-Viserver -server $Vcenter -username $VcUser -password $VcPassword | Out-Null
}


function WXVC
{
$Vcenter = "172.30.240.30"
$VcUser = "wxvcenter"
$VcPassword = "sicent!121"
$WINDOWS_TEMPLETE = "Template.windows2008.Welcome123"
$LINUX_TEMPLETE = "Template.JS.CentOS_6.3.Mini_jskj#123"
Add-PSSnapin -name *vmware*
Connect-Viserver -server $Vcenter -username $VcUser -password $VcPassword | Out-Null
}

function HZVC
{
$Vcenter = "172.30.134.101"
$VcUser = "administrator"
$VcPassword = "icebox#7788"
$WINDOWS_TEMPLETE = "Template.windows2008.Welcome123"
$LINUX_TEMPLETE = "Template.JS.CentOS_6.3.Mini_jskj#123"
$WINDOWS_TEMPLETE_OUT = "Template.out.windows2008.sicent!121"
$LINUX_TEMPLETE_OUT = "Template.out.windows2008.sicent!121"
Add-PSSnapin -name *vmware*
Connect-Viserver -server $Vcenter -username $VcUser -password $VcPassword | Out-Null
}

Write-Host
"<1> 连接成都VC
<2> 连接无锡VC
<3> 连接兴义VC"
do
{
    try {
    [ValidatePattern('1|2|3')]$VM_LOCATION = Read-Host "输入要连接的VC区域编号"
    } catch {}
} until ($?)

if ( $VM_LOCATION -eq "1" )
    {
    CDVC
    if ($? -eq "True")
        {
            Write-Host "连接到成都VC $Vcenter"
        }
    }
elseif ( $VM_LOCATION -eq "2" )
    {
    WXVC
    if ($? -eq "True")
        {
            Write-Host "连接到无锡VC $Vcenter"
        }
    }
elseif ( $VM_LOCATION -eq "3" )
    {
    HZVC
    if ($? -eq "True")
        {
            Write-Host "连接到兴义VC $Vcenter"
        }
    }


function CREATE_VM
{
                        #. $FILEROOT\invoke_parallel.ps1
                        #Import-Csv $CsvFile |Invoke-Parallel -scriptblock { ForEach-Object {
                        Import-Csv $CsvFile | ForEach-Object {
                        $name=$_.businesses+'_'+$_.ip+'_'+$_.system+'_'+$_.application #虚拟机命名组合
                        $custsysprep = Get-OSCustomizationSpec $_.system #获取自定义规范
                        $custsysprep | Set-OScustomizationSpec -NamingScheme Fixed -NamingPrefix $_.hostname #| Out-Null #配置主机名命名规则

                        get-vm $name -ErrorAction SilentlyContinue | Out-Null #校验是否有同名虚拟机
                        if ($? -eq "True") 
                            {
                            Write-Host "虚拟机 $name 已存在"
                            return
                            }

                        if ($_.type -eq "app")
                            {
                            if ($_.system -eq "Linux")
                            { $custsysprep | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $_.ip -SubnetMask $_.mask -DefaultGateway $_.gateway
                            $template = $LINUX_TEMPLETE
                            }
                            elseif ($_.system -eq "windows")
                            {$custsysprep | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $_.ip -SubnetMask $_.mask -DefaultGateway $_.gateway -dns $_.dns
                            $template = $WINDOWS_TEMPLETE
                            }

                            Write-Host "开始创建 $name"
                            New-vm -Name $name -Template $template -Datastore $_.datastore -resourcepool $_.resourcepool -Location $_.folder -OSCustomizationspec $custsysprep | set-vm -MemoryGB $_.memory -numcpu $_.cpu -Confirm:$false | Out-Null

                            if ($_.disk -ne 0)
                            {
                                Write-Host "添加磁盘"
                                get-vm -Name $name | New-HardDisk -CapacityGB $_.disk -Datastore $_.datastore -storageFormat Thin | Out-Null
                            }

                            if ($_.net -ne 0)
                            {
                                Write-Host "修改网卡配置"
                                get-vm -Name $name | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $_.net -Confirm:$false | Out-Null
                            }

                            Write-Host "创建完毕,正在启动虚拟机 $name "
                            Start-VM -vm $name -Confirm:$false | Out-Null
                            }

                          elseif ($_.type -eq "db" )
                            {
                            if ($_.system -eq "Linux")
                            { $custsysprep | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $_.ip -SubnetMask $_.mask -DefaultGateway $_.gateway
                            $template = $LINUX_TEMPLETE_DB
                            }
                            elseif ($_.system -eq "windows")
                            {$custsysprep | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $_.ip -SubnetMask $_.mask -DefaultGateway $_.gateway -dns $_.dns 
                            $template = $WINDOWS_TEMPLETE_DB
                            }

                            Write-Host "开始创建 $name"
                            New-vm -Name $name -Template $template -Datastore $_.datastore -resourcepool $_.resourcepool -vmhost $_.vmhost -Location $_.folder -OSCustomizationspec $custsysprep | set-vm -MemoryGB $_.memory -numcpu $_.cpu -Confirm:$false | Out-Null
    
                            if ($_.disk -ne 0)
                            {
                                Write-Host "添加磁盘"
                                get-vm -Name $name | New-HardDisk -CapacityGB $_.disk -Datastore $_.datastore -storageFormat Thin | Out-Null 
                            }

                            if ($_.net -ne 0)
                            {
                                Write-Host "修改网卡配置"
                                get-vm -Name $name | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $_.net -Confirm:$false | Out-Null
                            }

                            Write-Host "创建完毕,正在启动虚拟机 $name "
                            Start-VM -vm $name -Confirm:$false | Out-Null
                            }

                          elseif ($_.type -eq "out" )
                            {
                            if ($_.system -eq "Linux")
                            { $custsysprep | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $_.ip -SubnetMask $_.mask -DefaultGateway $_.gateway
                            $template = $LINUX_TEMPLETE_OUT
                            }
                            elseif ($_.system -eq "windows")
                            {$custsysprep | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $_.ip -SubnetMask $_.mask -DefaultGateway $_.gateway -dns $_.dns 
                            $template = $WINDOWS_TEMPLETE_OUT
                            }

                            Write-Host "开始创建 $name"
                            New-vm -Name $name -Template $template -Datastore $_.datastore -resourcepool $_.resourcepool -vmhost $_.vmhost -Location $_.folder -OSCustomizationspec $custsysprep | set-vm -MemoryGB $_.memory -numcpu $_.cpu -Confirm:$false | Out-Null
    
                            if ($_.disk -ne 0)
                            {
                                Write-Host "添加磁盘"
                                get-vm -Name $name | New-HardDisk -CapacityGB $_.disk -Datastore $_.datastore -storageFormat Thin | Out-Null 
                            }

                            if ($_.net -ne 0)
                            {
                                Write-Host "修改网卡配置"
                                get-vm -Name $name | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $_.net -Confirm:$false | Out-Null
                            }

                            Write-Host "创建完毕,正在启动虚拟机 $name "
                            Start-VM -vm $name -Confirm:$false | Out-Null
                            }
                        }
#}
}

#选择从文件或是从数据库导入信息"
Write-Host
"
选择从[本地]导入虚拟机信息,或是从[数据库]拉取虚拟机信息
"
do
{
    try {
    [ValidatePattern('y|Y|n|N')]$IMPORT_MODE = Read-Host "是否导入本地虚拟机信息 Y/N "
    } catch {}
} until ($?)
    if ( $IMPORT_MODE -eq 'y')
        {
            $FILEAVALIBLE = Test-Path $FILEROOT\vmlist.csv
            if ( $FILEAVALIBLE -eq 'True' ) #使用本地虚拟机信息,并执行
                {
                    $CsvFile = "$FILEROOT\vmlist.csv"
                    CREATE_VM
                }
            else
                {
                    Write-Host "找不到虚拟机信息文件,请检查 $FILEROOT\vmlist.csv 文件是否存在"
                    return
                }
        }
    elseif ( $IMPORT_MODE -eq 'n')
        {
             $SQLFILE = Split-Path -Parent $MyInvocation.MyCommand.Definition
             $CsvFile = "$SQLFILE\sqlout.csv"
             CREATE_VM
        }
