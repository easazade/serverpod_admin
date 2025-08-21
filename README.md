# Serverpod Admin

Administration panel for [serverpod](https://serverpod.dev) backend

# Get started

Add the library to dev dependencies

```yaml
dev_dependencies:
  serverpod_admin: ^x.y.z
```
Run below commands inside serverpod server project

```bash
serverpod generate # generates serverpod code
dart run serverpod_admin:main # generates admin panel pages/routes
```
**NOTE:** Run `dart run serverpod_admin:main` after each `serverpod generate`

Add the generated admin routes to serverpod webserver in `server.dart` in serverpod backend project.
```dart
void run(List<String> args) async {
  // ...
  if (pod.runMode == 'development') {
    appendAdminRoutes(pod);
  }
  // ... rest of the code
}  
```
The admin panel will be available on the serverpod webserver on `/admin` url.
eg: `localhost:8082/admin`

