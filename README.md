# Project Scripts

This repository contains a collection of utility scripts to automate development tasks.

## Laravel Scripts

Located in the `Laravel` directory, you'll find scripts to help with Laravel development:

### laravel-dependencies.ps1
A PowerShell script that handles Laravel project dependencies and includes:
- Administrative privilege check and elevation if needed
- Helper functions for formatted console output
- Dependency management utilities

### laravel-project.ps1
A PowerShell script for Laravel project management that includes:
- Project creation and setup automation
- Formatted console output for better visibility
- Laravel installer verification and installation
- Project configuration utilities

## Usage

The scripts are designed to be run in PowerShell and will automatically request administrative privileges if needed. Each script includes proper error handling and user feedback through formatted console output.

### Requirements
- Windows PowerShell
- Administrative privileges (scripts will auto-elevate if needed)