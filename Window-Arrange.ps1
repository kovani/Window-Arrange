if (("APIFuncs03" -as [type]) -eq $null){
        Add-Type  @"
        using System;
        using System.Runtime.InteropServices;
        using System.Collections.Generic;
        using System.Text;
        public class APIFuncs03
        {
            [DllImport("user32.dll")]
            [return: MarshalAs(UnmanagedType.Bool)]
            public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

            [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern int GetWindowText(IntPtr hwnd,StringBuilder lpString, int cch);

            [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
            public static extern IntPtr GetForegroundWindow();

            [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
            public static extern Int32 GetWindowThreadProcessId(IntPtr hWnd,out Int32 lpdwProcessId);

            [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
            public static extern Int32 GetWindowTextLength(IntPtr hWnd);

            [DllImport("user32.dll", SetLastError=true)]
            public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int W, int H, uint uFlags);

            [DllImport("user32.dll", SetLastError=true)]
            public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

            [DllImport("user32.dll", SetLastError=true)]
            public static extern bool SetForegroundWindow(IntPtr hWnd);

            [DllImport("user32")]
            public static extern bool EnumChildWindows(IntPtr window, EnumWindowProc callback, IntPtr i);
            public static List<IntPtr> GetChildWindows(IntPtr parent)
            {
               List<IntPtr> result = new List<IntPtr>();
               GCHandle listHandle = GCHandle.Alloc(result);
               try
               {
                   EnumWindowProc childProc = new EnumWindowProc(EnumWindow);
                   EnumChildWindows(parent, childProc,GCHandle.ToIntPtr(listHandle));
               }
               finally
               {
                   if (listHandle.IsAllocated)
                       listHandle.Free();
               }
               return result;
           }
           private static bool EnumWindow(IntPtr handle, IntPtr pointer)
           {
               GCHandle gch = GCHandle.FromIntPtr(pointer);
               List<IntPtr> list = gch.Target as List<IntPtr>;
               if (list == null)
               {
                   throw new InvalidCastException("GCHandle Target could not be cast as List<IntPtr>");
               }
               list.Add(handle);
               //  You can modify this to check to see if you want to cancel the operation, then return a null here
               return true;
           }
           public delegate bool EnumWindowProc(IntPtr hWnd, IntPtr parameter);
        }
public struct RECT
  {
    public int x1;        // x position of upper-left corner
    public int y1;         // y position of upper-left corner
    public int x2;       // x position of lower-right corner
    public int y2;      // y position of lower-right corner
  }
"@
}
CHCP 65001
Add-Type -assembly System.Windows.Forms

function Get-ChildWindow{
[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [ValidateNotNullorEmpty()]
    [System.IntPtr]$MainWindowHandle
)

BEGIN{
    function Get-WindowName($hwnd) {
        $len = [APIFuncs03]::GetWindowTextLength($hwnd)
        if($len -gt 0){
            $sb = New-Object text.stringbuilder -ArgumentList ($len + 1)
            $rtnlen = [APIFuncs03]::GetWindowText($hwnd,$sb,$sb.Capacity)
            $sb.tostring()
        }
    }

}

PROCESS{
    foreach ($child in ([APIFuncs03]::GetChildWindows($MainWindowHandle))){
        Write-Output (,([PSCustomObject] @{
            MainWindowHandle = $MainWindowHandle
            ChildId = $child
            ChildTitle = (Get-WindowName($child))
        }))
    }
}
}


function Set-WindowPosition{
[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline = $true, ValueFromPipelinebyPropertyName = $true)]
    [ValidateNotNullorEmpty()]
    [int]$X, [int]$Y, [int]$W, [int]$H,[System.IntPtr]$WHANDLE ,[int] $FLAGS=0x0040
    )
    PROCESS{
#        [APIFuncs03]::ShowWindow($WHANDLE,9)
        [APIFuncs03]::SetWindowPos($WHANDLE,0,$X,$Y,$W,$H,0)
#        [APIFuncs03]::SetForegroundWindow($WHANDLE)
    }
}

$main_form = New-Object System.Windows.Forms.Form
$main_form.Text ='WARRANGE'
$main_form.Size = "360,400"
$main_form.AutoSize = $true
$main_form.StartPosition = "CenterScreen"
$main_form.Topmost = $True
$main_form.MaximumSize = "360,400"
$main_form.MinimumSize = "360,400"

$loadbutton = New-Object System.Windows.Forms.Button
$loadbutton.Text = 'load'
$loadbutton.Location = "60,20"
$main_form.Controls.Add($loadbutton)
 
$savebutton = New-Object System.Windows.Forms.Button
$savebutton.Text = 'save'
$savebutton.Location = "200,20"
$main_form.Controls.Add($savebutton)

$outputBox = New-Object System.Windows.Forms.RichTextBox
$outputBox.Location = "10,60"
$outputBox.Size = "325,290"
$outputBox.MultiLine = $True
$outputBox.ScrollBars = "Vertical"
$outputBox.ReadOnly = $true
$main_form.Controls.Add($outputBox)

$loadbutton.Add_click({
    $loadfile = New-Object system.windows.forms.openfiledialog
    $loadfile.MultiSelect = $true
    $loadfile.Title = 'load'
    $loadfile.Filter = "TXT (*.txt)| *.txt"
    $resultloadfile = $loadfile.showdialog()
     if($resultloadfile -eq 'OK') {
        foreach ($Object in Get-Content -Encoding UTF8 -Path $loadfile.filename){
        $prop = $Object.Split(";")
        $title = -join ($prop[0].ToCharArray() | Select-Object -First 20)
        $outputBox.Text += $prop[0] + [System.Environment]::NewLine
        $WHANDLE= (Get-Process lsass | Get-ChildWindow | ? {$_.childtitle -like $("*" + $title + "*")}) | Select-Object -first 1
        Set-WindowPosition -X $prop[1] -Y $prop[2] -WHANDLE $WHANDLE.ChildId -W $prop[3] -H $prop[4] -FLAGS 0x0010       
        }
     }
})

$savebutton.Add_click({
    $file = @()
    $savefile = New-Object system.windows.forms.savefiledialog
    $savefile.Title = 'save'
    $savefile.Filter = "TXT (*.txt)| *.txt"
    $resultsavefile = $savefile.showdialog()
    if($resultsavefile -eq 'OK') {
        $Windowrect = New-Object RECT
        foreach ($windowstring in Get-Content -Encoding UTF8 -Path $savefile.filename){
                $windowprop = $windowstring.Split(";")
                $window = ((Get-Process lsass | Get-ChildWindow | ? {$_.childtitle -like $("*" + $windowprop[0] + "*")}) | Select-Object -first 1)
                [APIFuncs03]::GetWindowRect($window.childid, [ref]$Windowrect)
                $h = $Windowrect.y2 - $Windowrect.y1
                $w = $Windowrect.x2 -$Windowrect.x1
                $stringoffile = $windowprop[0] + ";" + $Windowrect.x1 + ";" + $Windowrect.y1 + ";" + $w + ";" + $h
                $file += $stringoffile
        }
     }
     $outputBox.Text += $file + [System.Environment]::NewLine
    $file | Out-File -FilePath $savefile.FileName
})

$main_form.ShowDialog()
