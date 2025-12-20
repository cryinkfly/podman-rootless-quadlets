### Storage limit per source/user

In config.yaml, you can set a quota for each source:

```
srver:port: 80
  baseURL: "/"
  logging:
    - levels: "info|warning|error"
  sources:
    - path: "/files/user1"
      name: "Max"
      quota: 1073741824    # 1 GB in bytes
    - path: "/files/user2"
      name: "Lisa"
      quota: 536870912     # 512 MB



```

- quota is specified in bytes
- When the user reaches the limit, they cannot upload any more files
