# plugin_ci

Contains scripts to do automated testing and deployment for QGIS plugins.
These scripts are written for and tested on the services GitHub, travis-ci and transifex.

## Base functionality

 - Automatically push plugin releases to the QGIS plugin repository
 - Automatically upload plugin releases to GitHub releases
 - Create releases and write the changelog for releases on the GitHub web interface
 - Push translation source strings to transifex on commits to master
 - Pull the latest translations from transifex on release

## Advanced functionality

 - Create a custom repository for QGIS plugins:
   https://raw.githubusercontent.com/QGEP/qgepplugin/master/plugins.xml

# Quickstart guide

From the root directory of the plugin repository

```sh
git submodule add https://github.com/opengisch/plugin_ci.git
cp plugin_ci/templates/.* .
```

 - Activate travis-ci for the plugin repository
 - On travis-ci go to *More Options* -> *Settings* and add those variables. Since they are login credentials, do *not* activate the "Dispay value in build log".
 
   - `OSGEO_USERNAME`
     - The name of the OSGeo account to which the plugin will be uploaded
   - `OSGEO_PASSWORD`
     - The password of the OSGeo account to which the plugin will be uploaded
   - `GH_TOKEN`
     - https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
     - activate *repo_deployment*.
   - `TX_TOKEN`
     - Create a token on the transifex web interface
 
# Rules to follow

- Put the code in a subfolder of the plugin and not in the main folder. The subfolder should have the same name as the repository.
- 

# Activating unit tests

There is an example of enabling unit tests in [the projectgenerator plugin](https://github.com/opengisch/projectgenerator/blob/master/.travis.yml).

# Sample plugins
  - https://github.com/opengisch/qgis_swiss_locator
  - https://github.com/opengisch/projectgenerator
    - Contains unit tests against different QGIS versions
  - https://github.com/opengisch/qfieldsync
  - https://github.com/opengisch/quick_attribution
    - Minimal example
  
