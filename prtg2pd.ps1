# Powershell script to trigger and resolve PRTG alerts in PagerDuty using the events v2 API

# Notes
# Copy the line below (exluding the hash) into the parameters field in the PRTG notification template
# '%probe' '%device' '%deviceid' '%sensor' '%sensorid' '%group' '%groupid' '%home' '%host' '%status' '%colorofstate' '%down' '%priority' '%message' '%comments' '%datetime' 'critical\warning\info'

# Ingest the alert payload from PRTG

# TODO Update README.md for the proper parameter usage.

Param(
    [string]$probe,
    [string]$device,
    [string]$deviceid,
    [string]$sensor,
    [string]$sensorid,
    [string]$group,
    [string]$groupid,
    [string]$prtg_home,
    [string]$prtg_host,
    [string]$status,
    [string]$colorofstate,
    [string]$down,
    [string]$priority,
    [string]$message,
    [string]$comments,
    [string]$datetime,
	[string]$Severity
)

# TODO Change PD RoutingKey to passed arguement and not hardcoded.DESCRIPTION
#  Moving this to a command line arguement will allow you to use one script
#  to alert to multiple services in PagerDuty.  This will allow for flexability
#  when alerting and with business service dependancies.

# ---------------------------------
# PagerDuty API Routing Key and Url
# ---------------------------------
# Change the $RoutingKey field to the value set by the Event API v2 integration
# settings for the PagerDuty service you wish to route alerts to.
# DO NOT CHANGE THE URL.
$RoutingKey = "3e94479ab3e14704c0a27ce59a8cbfb5"
$Url = "https://events.pagerduty.com/v2/enqueue"
# ---------------------------------

# ---------------------------------
# This code was commented out as it did not work for my purposes.
# ---------------------------------
# Determine the Event Action
#$regex = [regex] "\((.*)\)"
#$action = $regex::match($status, $regex).groups[1]

#switch ($action) {
#    "Up" { $PDevent = "resolve" }
#    default { $PDevent = "trigger" }
#}

# ---------------------------------
# Determine if you should open, acknowledge, or resolve this incident.
# ---------------------------------
switch ($status) {
    "Up" { $PDevent = "resolve" }
    "Down (Acknowledged)" { $PDevent = "acknowledge" }
    "Paused" { $PDevent = "acknowledge" }
    default { $PDevent = "trigger" }
}

# ---------------------------------
# This code was commented out as it did not work for my purposes.
# ---------------------------------
# Determine the Severity
#switch ($colorofstate) {
#    "#b4cc38"	{ $Severity = "info" }
#    "#ffcb05"	{ $Severity = "warning" }
#    #   "Error"		{$Severity="error"}
#    "#d71920"	{ $Severity = "critical" }
#    default { $Severity = "critical" }
#}

$Description = "$device $sensor $status $down"
# $Severity = "critical"
$Timestamp = Get-Date -UFormat "%Y-%m-%dT%T%Z"

$AlertPayload = @{
    routing_key  = $RoutingKey
    event_action = $PDevent
    dedup_key    = "$deviceid-$sensorid"
    client       = "PRTG Network Monitor"
    client_url   = $prtg_home
    payload      = @{
        summary        = $Description
        timestamp      = $Timestamp
        source         = $device
        severity       = $Severity
        component      = $group
        class          = $sensor
        custom_details = @{
            prtg_server  = $prtg_home
            probe        = $probe
            group        = $group, $groupid
            device       = $device, $deviceid
            sensor       = $sensor, $sensorid
            url          = $prtg_host
            colorofstate = $colorofstate
            down         = $down
            downtime     = $downtime
            priority     = $priority
            message      = $message
            datetime     = $datetime
            comments     = $comments
            status       = $status
        }
    }
}

# Convert Events Payload to JSON

$json = ConvertTo-Json -InputObject $AlertPayload

$logEvents = "C:\pagerduty\logs\prtg2pd_log.txt"

Add-Content -Path $logEvents -Value $Url
Add-Content -Path $logEvents -Value $json

# Send to PagerDuty and Log Results

$LogMtx = New-Object System.Threading.Mutex($False, "LogMtx")
$LogMtx.WaitOne() | Out-Null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

try {
    Invoke-RestMethod	-Method Post `
        -ContentType "application/json" `
        -Body $json `
        -Uri $Url `
    | Out-File $logEvents -Append
}

finally {
    $LogMtx.ReleaseMutex() | Out-Null
}
