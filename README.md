# HomeApplicationsClient

A new Flutter project.

# How to build
Download: https://github.com/google/bundletool

Run:
```
flutter build appbundle
```

Run:
```
java -jar .\bundletool-all-1.18.1.jar build-apks --bundle="F:\projekte\homeApplicationsClient\build\app\outputs\bundle\release\app-release.aab" --output="F:\projekte\homeApplicationsClient\homeApplicationsClient.apks"
```

Install to connected device:
```
java -jar .\bundletool-all-1.18.1.jar install-apks --apks="F:\projekte\homeApplicationsClient\homeApplicationsClient.apks"
```