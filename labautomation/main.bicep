// Per-attendee ARM compatibility template.
// Shared resources, including the user-data storage account and per-user CSV
// containers, are created by shared.bicep. The per-attendee hook creates the
// attendee databases, Fabric workspace, SQL access, and CSV upload in PowerShell.

@description('Azure region. Kept for compatibility with deployment helpers.')
param location string = resourceGroup().location

@description('Entra object ID of the attendee. Kept for compatibility with deployment helpers.')
param attendeeObjectId string

output attendeeObjectId string = attendeeObjectId
output location string = location
