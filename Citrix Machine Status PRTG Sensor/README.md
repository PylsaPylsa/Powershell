# Citrix Machine Status PRTG sensor
This is a custom EXE/XML PRTG sensor to check Citrix XenApp/XenDesktop machine status per Delivery Group. Returns an XML response for PRTG.

## Prerequisites
- Install PowerShell Broker snapins for Citrix. These snapins are included in the installation ISO for XenApp/XenDesktop in the location x64\Citrix Desktop Delivery Controller folder. Use the MSI to install the snapins on the (remote) probe that has access to the delivery controller.
- Service account that has Administrator (read-only) permissions granted on the Citrix delivery controller.