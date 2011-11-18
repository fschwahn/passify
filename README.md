# passify
`passify` is a command line interface (CLI) for [Passenger](http://www.modrails.com/), equivalent to what [powder](https://github.com/Rodreegez/powder) and [powify](https://github.com/sethvargo/powify) are for [pow](http://pow.cx/). I used the [PassengerPane](https://github.com/Fingertips/passengerpane), however I wanted the simplicity and speed of a CLI for that task.

## Installation
    gem install passify

## Usage
`passify` is fully compatible with the PassengerPane, and only runs on MacOSX right now. The first step after the installation is to run the `install`-command:

    passify install

This is necessary to ensure that Apache is set up correctly. If Passenger and the PassengerPane are already installed this command does nothing. To create a new application enter the application path and run

    passify add [name]

The application name is optional, if none is provided `passify` creates the name from the current working directory. After creating an application it can be opened in the browser by running

    passify open

To restart the application run

    passify restart

To remove the application run

    passify remove

To change the rack environment to e.g. production run

    passify env production

To show the current rack environment run

    passify env

A list of all applications served with `passify` can be viewed by running

    passify list

Last but not least, `passify` can be removed from Apache by running

    passify uninstall

Please note that this will also disable the PassengerPane. If you don't want to use `passify` anymore, but keep on using PassengerPane, just remove the gem:

    gem uninstall passify

### RVM
It makes sense to create a wrapper for `passify` if you are using multiple versions of ruby. If `passify` as installed for MRI 1.8.7, run the following command:

    rvm wrapper 1.8.7 --no-prefix passify

## Changelog
### 0.2.0
* create a `.passify` file to save the host
* added `-h` and `-v` shortcuts

### 0.1.2
* added env-command to change rack environment

### 0.1.1
* added support for legacy application

### 0.1.0
* initial release

## License
Released under the MIT License. See the LICENSE file for further details.