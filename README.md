# Azure Update Manager Maintenance Configurations

Copyright (c) September 2026 
<br>Shannon Eldridge-Kuehn

Create Azure Update Manager maintenance configurations for guest patching:

- Windows: monthly, second Tuesday, with a four-day offset
- Linux: daily

The repository includes equivalent Bash and PowerShell scripts for creating the configurations and assigning virtual machines. The creation scripts prompt for the resource group, Azure region, time zone, schedule start date, and subscription ID. The assignment scripts prompt for the VM resource group, configuration resource group, configuration names, and subscription ID. The patch classifications, reboot behavior, maintenance windows, and default configuration names are retained from the original working configuration.

## Prerequisites

- Azure CLI installed and available as `az`
- An Azure account with permission to create resource groups and Microsoft.Maintenance configurations
- Bash for the `.sh` scripts, or PowerShell for the `.ps1` scripts
- An Azure CLI login (`az login`); the scripts use the current subscription as the default when available

## Run

Bash:

```sh
chmod +x scripts/create-maintenance-config.sh
./scripts/create-maintenance-config.sh
```

PowerShell:

```powershell
./scripts/create-maintenance-config.ps1
```

The subscription prompt defaults to the subscription ID from the active Azure CLI context. Press Enter to accept it, or enter another subscription ID. The script creates the resource group if it does not already exist, then creates or updates the two maintenance configurations in that group.

## Assign Virtual Machines

After creating the maintenance configurations, run the assignment script for your shell:

```sh
./scripts/assign-maintenance-configs.sh
```

```powershell
./scripts/assign-maintenance-configs.ps1
```

Enter the resource group containing the VMs. The configuration resource group defaults to the VM resource group, and the configuration names default to `mc-windows-monthly` and `mc-linux-daily`. The script lists VMs only in the selected VM resource group, assigns Windows VMs to the Windows configuration and Linux VMs to the Linux configuration, and reports any VMs with an unknown OS type without assigning them. It uses the stable assignment name `update-manager`, so rerunning it updates those assignments.

## Schedule details

The entered start date is used for both schedules. The Windows window starts at 22:00 and lasts 3 hours 55 minutes. The Linux window starts at 02:00 and lasts 2 hours. Both use the time zone you enter and reboot only if required.

Windows patch classifications: Critical, Security, UpdateRollup, Definition, and Updates.

Linux patch classifications: Critical and Security.

Review the selected subscription, region, time zone, and start date before running. Azure CLI commands perform real changes in the selected subscription.

## License

MIT. See [LICENSE](LICENSE) for the full license text.
