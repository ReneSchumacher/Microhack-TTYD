---
name: micro-hack
description: A prompt using the Ember agent from 1ES to add the MicroHack automation framework to this hack repository.
agent: Ember
model: Claude Opus 4.8 (copilot)
---

Hi Ember!

Please help me to move this project to the MicroHack automation framework. We need to do this in two phases:

1. **Change infrastructure deployment from Terraform to Bicep.**  
   While the MicroHack automation framework supports Terraform, there are issue when deployments fail and must be retried due to Terraform state handling. Thus, we want to move to Bicep for infrastructure deployment.

2. **Change deployment from azd to MicroHack automation framework.**  
   The automation framework of the MicroHack app follows its own logic, which doesn't match well with Azure Developer CLI (azd).


## Additional information
You can find the documentation of the MicroHack automation framework at https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md. Pay attention to the general structure: one shared deployment script per subscription, one deployment script per MicroHack attendee/lab. Since this project is designed to have many attendees in one subscription, I propose the following setup:

- We will put a maximum of 42 attendees in one subscription.
- For each subscription, we provision one shared SQL Managed Instance and one shared Fabric F32 instance.
- For each attendee/lab, we provision two databases in the shared SQL instance and one Workspace in the shared Fabric instance.

## Step by Step
Since we're in a Git repository, commit intermediate results whenever you reach a stable state. It's better you have small, incremental changes you can go back to instead of having to throw away all changes after a while and start from scratch. It also makes it easier for me and others to understand what you did ;-)

## Feedback loop
After adding the MicroHack automation framework to this project, follow the instructions at https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md#local-testing to test your changes locally. For the interactive logins, please ask me for help, don't try to log in yourself. My setup is a bit more complex and requires the use of the correct user to access my test subscription!

## Don't make assumptions - ask
If you're unsure about anything, please ask! We're in this together, you don't have to know everything and tackle every problem yourself.