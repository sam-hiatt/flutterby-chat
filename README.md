# Flutterby Chat mIRC Scripts

This repository contains mIRC scripts designed for use with [Flutterby Chat](https://flutterby.chat/) servers.

The scripts are intended to provide a basic foundation that other mIRC users can modify, extend, and build upon.

## Scripts

### `flutterby_chat.mrc`

The primary Flutterby Chat integration script.

#### Features

##### 1. Secure Account Credential Storage

The script stores the email address and password for a single account that has already been registered on Flutterby Chat.

- The email address is stored in plain text as a persistent mIRC variable.
- The password is stored in a DPAPI-protected encrypted file at:

```text
%USERPROFILE%\flutterby_password.sec
```

When configuring the password, the script prompts for the password associated with the stored email address. It then uses mIRC's `/run` command to invoke PowerShell and perform the required encryption.

The password is encrypted for the current Windows user account. It can later be decrypted by the `get_flutterby_password` alias when the script needs to authenticate.

> [!NOTE]
> This functionality has currently only been tested on Windows 11 Pro, OS Build `26200.8875`. It may not work as expected on other Windows versions or configurations.

##### 2. Configurable Debugging

The script includes several debugging options:

- Enable or disable a dedicated debug window.
- Select a debug output level from `1` through `4`.
- View additional connection, authentication, socket, and server-routing information.

##### 3. Unified Connection to Regional Flutterby Servers

Flutterby Chat uses multiple regional servers, and channels may be hosted on any of them.

The script opens sockets to the available regional servers and combines their responses into a single mIRC server session. Where possible, responses are rewritten or forwarded so that mIRC interprets them as originating from one unified server connection.

This behavior is most clearly demonstrated when using the IRC `LIST` command. Channel-list responses from multiple regional servers are collected and presented through the same mIRC session.

##### 4. Basic Nickname Changer

The script provides a simple nickname-changing function.

It connects to the appropriate Flutterby endpoints and submits the requested nickname change.

Current limitations include:

- Minimal error handling.
- Limited handling of special characters.
- Limited handling of uncommon nickname edge cases.
- No guarantee that every server-side validation response will be displayed cleanly.

---

### `flutterby_passport_grabber.mrc`

A standalone script used only to retrieve a Flutterby authentication token.

Unlike `flutterby_chat.mrc`, this script does not permanently store the email address or password. It prompts for both values whenever a token retrieval request is made.

When authentication succeeds, the returned token is stored as the following persistent mIRC variable:

```text
%passport_token
```

This script may be useful for testing authentication, troubleshooting login requests, or retrieving a token without using the complete Flutterby Chat integration script.

## Requirements

- mIRC
- Windows with PowerShell available
- An existing registered Flutterby Chat account
- Network access to the Flutterby Chat website, API, and regional chat servers

## Security Notes

- The email address used by `flutterby_chat.mrc` is stored in plain text as a mIRC variable.
- The password is encrypted using Windows Data Protection API functionality through PowerShell.
- The encrypted password is normally only decryptable by the same Windows user account on the same Windows installation.
- The standalone passport grabber temporarily handles the entered email address and password during the authentication request but does not intentionally save them as persistent variables.
- Authentication tokens should be treated as sensitive credentials and should not be shared or committed to this repository.

## Project Status

These scripts are experimental and are provided as a starting point for other mIRC users.

They may contain incomplete functionality, limited error handling, and assumptions specific to the author's Windows and mIRC environment. Review and test the scripts carefully before relying on them.
