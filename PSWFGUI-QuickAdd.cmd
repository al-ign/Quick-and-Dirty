# 2> nul & powershell.exe -ExecutionPolicy Bypass -NoProfile -Command "[scriptblock]::Create((Get-Content -LiteralPath '%~f0' -Raw)).Invoke()" #& EXIT /B

# load Forms
Add-Type -assembly System.Windows.Forms

$main = [System.Windows.Forms.Form]::new()
$main.AutoSize = $true

# array to rule^W hold them all
$global:controls = [System.Collections.ArrayList]::new()

#listview
$list = [System.Windows.Forms.ListView]::new()
[void]$controls.Add($list)

# Text box
$textBox_Rules = [System.Windows.Forms.TextBox]::new()
[void]$controls.Add($textBox_Rules)

# lazy control creation
function CreateControl {
[cmdletBinding()]
    param ($Prefix, $Type, [Parameter(ValueFromPipeline=$true)]$Control)
    process {
        foreach ($thisControl in $Control) {
            $thisVar = New-Variable -Name ($Prefix + '_' + ($thisControl.Text -replace '\s')) -Value $(New-Object $type) -PassThru -Force -Scope global
            $thisVar.Value.Location = $thisControl.Location
            $thisVar.Value.Text = $thisControl.Text

            [void]$global:controls.Add($thisVar.Value)
            }
        }
    }

$arrButtons = @( 
    @{
        Location = '810,30'
        Text = 'Refresh'
        }
    @{
        Location = '810,60'
        Text = 'Add rule'
        }
    )

$arrButtons | CreateControl -Prefix Button -Type 'System.Windows.Forms.Button'

# Checkboxes
$arrCheckBoxes = @(
    @{
        Location = '900,30'
        Text = 'Inbound'
        }
    @{
        Location = '900,60'
        Text = 'Outbound'
        }
    @{
        Location = '1010,30'
        Text = 'TCP'
        }
    @{
        Location = '1010,60'
        Text = 'UDP'
        }
    )

# create checkboxes and add them to the controls array
$arrCheckBoxes | CreateControl -Prefix checkBox -Type 'System.Windows.Forms.CheckBox'

# "precheck" defaults
$checkBox_Inbound.Checked = $true
$checkBox_TCP.Checked = $true 


# refresh the process list
$button_Refresh_Click = {
    $ps = Get-Process | select Name, Id, Path

    $list.Clear()

    [void]$list.Columns.Add('Name', 100)
    [void]$list.Columns.Add('Id', 30)
    [void]$list.Columns.Add('Path', -2)

    foreach ($thisPs in $ps) {

        $listItem = [System.Windows.Forms.ListViewItem]::new($thisPs.name)
        $listItem.SubItems.Add($thisPs.Id)

        if ($thisPs.Path) {
            $listItem.SubItems.Add($thisPs.Path)
            }
        $list.Items.Add($listItem)
        }

    }

$button_Refresh.add_click($button_Refresh_Click)

# Execute the contents of the textbox
$button_AddRule_Click = {
    Invoke-Command -ScriptBlock ([scriptblock]::Create($textBox_Rules.Text))
    }

$button_AddRule.Add_Click($button_AddRule_Click)

# TextBox
$textBox_Rules.Location = '810,100'
$textBox_Rules.Size = '500,500'
$textBox_Rules.Multiline = $true
#$textBox_Rules.Anchor = 'Bottom,Right'
#$textBox_Rules.MinimumSize = '300,200'
#$textBox_Rules.MaximumSize = '1000,900'
$textBox_Rules.ScrollBars = 'Both'
$textBox_Rules.Text = @"
Select the process (or multiple processes), check the needed checkboxes, press Add rule.

Be careful, content of this TextBox would be executed AS IS
"@

# hack a bigger font size for the textbox
$textBox_Rules.Font = [System.Drawing.Font]::new($textBox_Rules.Font.FontFamily, ($textBox_Rules.Font.Size + 4))

# list view
$list.Anchor = 'Top, Bottom, Left'
$list.GridLines = $true
$list.FullRowSelect = $True
$list.View = 'Details'
$list.FullRowSelect = $true
$list.Location = '0,0'
$list.Size = '800,560'
$list.MultiSelect = $true

# Populate the textbox with a firewall rules 
$list_Click = {
    $text = @()
    foreach ($thisItem in $list.SelectedItems) {

        foreach ($direction in ($checkBox_Inbound,$checkBox_Outbound | where {$_.Checked} | Select -expandproperty Text) ){ 
            foreach ($proto in ($checkBox_TCP,$checkBox_UDP | where {$_.Checked} | Select -expandproperty Text) ){ 
    
                $text += "New-NetFirewallRule -Direction {0} -Protocol {1} -DisplayName '{2}' -Program '{3}'" -f $direction, $proto, $thisItem.Subitems[0].Text, $thisItem.Subitems[2].Text
                $text += ""
                } 
            }
        }
    $textBox_Rules.Text = $text -join [System.Environment]::NewLine
    }

$list.Add_Click($list_Click)

# add controls to the main window
foreach ($thisControl in $controls) {
    $main.Controls.Add($thisControl)
    }

# populate the list at the start
$tmp = & $Button_Refresh_Click

# display the main window
$main.ShowDialog()

