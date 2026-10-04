# addon-packaging Specification

## Purpose
Defines how Paseo is published and installed as a Home Assistant add-on: the add-on repository, manifest, supported platforms, branding, documentation and build pipeline.

## Requirements

### Requirement: Installable add-on repository
The repository SHALL be a valid Home Assistant add-on repository that users can add by URL in the Add-on Store and that lists a single add-on named "Paseo".

#### Scenario: Add repository to Home Assistant
- **WHEN** a user adds the repository URL under Settings → Add-ons → Add-on Store → Repositories
- **THEN** the store shows a "Paseo" add-on with a description, version and install button

#### Scenario: Install the add-on
- **WHEN** the user installs and starts the Paseo add-on with default options
- **THEN** the Supervisor pulls the image without errors and the add-on reaches the "started" state

### Requirement: Public source repository
The add-on SHALL be hosted in the public GitHub repository `https://github.com/farajfarook/paseo-ha-addon` under an open-source license, and that URL SHALL be the repository URL users add to Home Assistant.

#### Scenario: Anonymous access
- **WHEN** an unauthenticated user opens or clones `https://github.com/farajfarook/paseo-ha-addon`
- **THEN** the repository contents, license and README are accessible

### Requirement: Pre-built images
Each add-on release SHALL have publicly pullable pre-built images for every supported architecture, tagged with the add-on version, so Home Assistant downloads the image instead of building it on the device.

#### Scenario: Install pulls image
- **WHEN** a user installs or updates the add-on
- **THEN** the Supervisor pulls the image for the host architecture matching the add-on version without any registry login, and does not build locally

#### Scenario: Release publishes all architectures
- **WHEN** a release tag matching the add-on version is pushed
- **THEN** images for `aarch64` and `amd64` tagged with that version become publicly available

#### Scenario: Version mismatch blocked
- **WHEN** a release tag does not match the add-on version in the manifest
- **THEN** publishing fails and no images are pushed

### Requirement: Supported architectures
The add-on SHALL declare and build for `aarch64` and `amd64`, each on the corresponding Home Assistant base image.

#### Scenario: Install on a 64-bit ARM host
- **WHEN** the add-on is installed on an `aarch64` host (e.g. Raspberry Pi 4/5, HA Green)
- **THEN** an `aarch64` image is used and the add-on starts

#### Scenario: Install on an x86-64 host
- **WHEN** the add-on is installed on an `amd64` host
- **THEN** an `amd64` image is used and the add-on starts

#### Scenario: 32-bit ARM host not supported
- **WHEN** the add-on is viewed on an `armv7` (32-bit ARM) host
- **THEN** the add-on does not list `armv7` in its architectures, so the Supervisor does not offer it there, and the documentation states that 32-bit systems are unsupported and points Raspberry Pi 3/4 users to the 64-bit HAOS image

### Requirement: Pinned Paseo version
Each add-on release SHALL install one explicit, pinned Paseo version, and the add-on version SHALL make that Paseo version identifiable.

#### Scenario: Version is visible
- **WHEN** a user views the add-on in the store or its changelog
- **THEN** they can determine which Paseo version the add-on release contains

#### Scenario: Reproducible build
- **WHEN** the same add-on release is built twice
- **THEN** both builds install the same Paseo version

### Requirement: Paseo branding
The add-on SHALL use the Paseo logo as its store icon and logo images.

#### Scenario: Store listing shows Paseo logo
- **WHEN** a user browses the add-on store or the installed add-on page
- **THEN** the Paseo logo is displayed as the add-on icon

### Requirement: User documentation
The add-on SHALL ship documentation shown in the Home Assistant UI that explains installation, every configuration option, agent authentication, workspace locations, and the security/trust model.

#### Scenario: Documentation tab
- **WHEN** the user opens the add-on's Documentation tab
- **THEN** they see setup instructions, an options reference and a security section stating that agents can read and write mounted folders

#### Scenario: Option descriptions in configuration form
- **WHEN** the user opens the add-on's Configuration tab
- **THEN** each option has a human-readable name and description

### Requirement: Continuous integration
The repository SHALL have CI that lints the add-on configuration and builds the image for every supported architecture on each pull request and push to the default branch.

#### Scenario: Invalid manifest is caught
- **WHEN** a change introduces an invalid add-on configuration
- **THEN** the CI lint job fails

#### Scenario: Build per architecture
- **WHEN** CI runs on a pull request
- **THEN** an image build is attempted for `aarch64` and `amd64` and failures are reported per architecture
