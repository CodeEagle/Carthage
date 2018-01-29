

> Official `Carthage` [README](https://github.com/Carthage/Carthage/blob/master/README.md)

Features
===
- merge [Cached lastest remote version to avoid blocked fetching in poor network environment](https://github.com/Carthage/Carthage/pull/2307)
- merge [Add configuration support for Carthage](https://github.com/Carthage/Carthage/pull/2312)


[Usage of PR 2312](https://github.com/Carthage/Carthage/pull/2312)
---
> # Features
> - config build options in `Carthage.private`
> - can override repo to local project
> - show cost time
>
> # Motivation
> - Quit typing config for `Carthage` every time you build your dependencies
> - Manual manager dependencies repositories by using `override` feature
>
> # Usage
> Configuration Template(write in `Cartfile.private`)
>
```
#cache-builds: true/false, default false
#verbose: true/false, default false
#configuration: Release/Debug or other
#new-resolver: true/false, default false
#use-ssh: true/false, default false
#use-submodules: true/false, default false
#platforms:  macOS, iOS, watchOS, tvOS ,remove for all platform
#skip: Alamofire, Alamofire.xcworkspace, Alamofire iOS
#override: Alamofire, ../Alamofire
```
>
> ## `skip`
> Can just config `Name` parameter , all build of the `Dependency` will being skilled.
>
> - `Name`:  first parameter, `Dependency`'s property `name`,  when using local path for repo address, last component will treat as `name`, such as `/path/to/your/ProjectName`
`Name` is case sensitive(using as a key).
> - `ProjectName`:  second parameter, using whit third parameter, the name of project
> - `SchemeName`: third  parameter, the scheme name
>
> ## `override`
>
> - `Name`: see above
> - `Address`: new git address for the `Dependency`, can be local or remote
