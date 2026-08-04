# Upstream provenance

IDCFlare is a modified distribution of [Lingyan000/fluxdo](https://github.com/Lingyan000/fluxdo).

## Imported baseline

- FluxDO commit: `5cfa2e3813ebe2c5feebc9a0d09814bb4ef18a0b`
- FluxDO release line: `v0.2.25`
- `core/doh_proxy`: `08d3468f0a1eb2858840c525d61f8aa888696522`
- `packages/fluxdo_render`: `6a0f26c6ea7f5978f2bb2a3b94f5b3736f1fb238`

The upstream Git metadata was not copied into this project tree. The two upstream submodule source trees were imported with the application source so a checkout remains buildable without nested Git repositories.

## IDCFlare changes

- Replaced the site endpoint, trusted domains and deep-link handling with IDC Flare values.
- Replaced visible application branding and platform icons with IDC Flare assets.
- Changed platform identifiers and release artifacts to `com.fdcflare.client` / `idcflare`.
- Disabled Linux.DO-only Credit, CDK, Connect and metaverse integrations.
- Disabled upstream application updates and crash reporting until independent services are configured.

Internal package names, native method-channel identifiers and the `fluxdo_render` package name are intentionally retained where renaming would add compatibility risk without changing user-visible behavior.

## License

FluxDO is distributed under GNU GPL v3. IDCFlare keeps the same `LICENSE` and provides this provenance record so upstream authorship and the modified nature of this distribution remain clear.
