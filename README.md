# terramate-atlantis-autoplan

A small [Terramate](https://terramate.io) repository planned by
[Atlantis](https://www.runatlantis.io), with **no generated code in git**:
neither Terramate's generated Terraform nor `atlantis.yaml`. Atlantis
generates both in every pull request, and
[terramate-atlantis-config](https://github.com/devops-roast/terramate-atlantis-config)'s
`when_modified_from_config` makes it plan exactly the stacks a change
affects, even when the change is outside the stacks.

- Blog post: [Planning Terramate stacks in Atlantis without generated code](https://oponomarov.com/blog/posts/planning-terramate-stacks-in-atlantis-without-generated-code/)
- Start here instead if you're new to the tool:
  [terramate-atlantis-demo](https://github.com/shmileee/terramate-atlantis-demo)
  and [Generating Atlantis config from Terramate stacks](https://oponomarov.com/blog/posts/generating-atlantis-config-from-terramate-stacks/)

## What to look at

| Path | What it shows |
| --- | --- |
| [`.terramate-atlantis.yaml`](.terramate-atlantis.yaml) | `when_modified_from_config` and stack ordering, switched on |
| [`atlantis/repos.yaml`](atlantis/repos.yaml) | the two hooks: `terramate generate`, then `terramate-atlantis-config generate` |
| [`.gitignore`](.gitignore) | the generated files that stay out of git |
| [Pull requests](https://github.com/shmileee/terramate-atlantis-autoplan/pulls) | one per kind of change, with what to look for in the description |

| A pull request that changes only | is planned for |
| --- | --- |
| `stacks/aws/acme-development/account.tm.hcl` | the two stacks in that account |
| `stacks/imports/aws.tm.hcl` | the four AWS stacks that import it |
| `modules/shared/main.tf` | the two stacks that call it |
| `config/settings.json` | the stack that lists it in `watch` |

The stacks only hold `terraform_data` resources, so they plan without cloud
credentials. Tool versions are pinned in [`mise.toml`](mise.toml).

## Running it yourself

Fork the repository, then:

```sh
mise install   # the pinned tools
make app       # once: create a GitHub App for Atlantis, install it on the fork
make up        # start Atlantis, reachable by GitHub through a free tunnel
make e2e       # open the example pull requests and check Atlantis' answers
make down
```
