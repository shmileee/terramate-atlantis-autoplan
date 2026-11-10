# terramate-atlantis-autoplan

A small [Terramate](https://terramate.io) repository planned by
[Atlantis](https://www.runatlantis.io), with **no generated code in Git**:
neither Terramate's generated Terraform nor `atlantis.yaml`. Atlantis
generates both in every pull request, and
[terramate-atlantis-config](https://github.com/devops-roast/terramate-atlantis-config)'s
`when_modified_from_config` makes it plan exactly the stacks a change
affects, even when the change is outside the stacks.

This is the example repository for
[Planning Terramate stacks in Atlantis without generated code](https://oponomarov.com/blog/posts/planning-terramate-stacks-in-atlantis-without-generated-code/).
If you're new to the tool, start with
[Generating Atlantis config from Terramate stacks](https://oponomarov.com/blog/posts/generating-atlantis-config-from-terramate-stacks/)
and its repository,
[terramate-atlantis-demo](https://github.com/shmileee/terramate-atlantis-demo).

## What to look at

| Path | What it shows |
| --- | --- |
| [`.terramate-atlantis.yaml`](.terramate-atlantis.yaml) | `when_modified_from_config` and stack ordering, switched on |
| [`atlantis/repos.yaml`](atlantis/repos.yaml) | the two hooks, in order: `terramate generate`, then `terramate-atlantis-config generate` |
| [`atlantis/docker-compose.yaml`](atlantis/docker-compose.yaml) | the Atlantis server: a failing hook stops the run |
| [`stacks/aws/acme-development/eu-west-1/app/stack.tm.hcl`](stacks/aws/acme-development/eu-west-1/app/stack.tm.hcl) | `after = ["../network"]`, which becomes Atlantis' `depends_on` |
| [`.gitignore`](.gitignore) | the generated files that stay out of Git |

The stacks only hold `terraform_data` resources, so they plan without cloud
credentials. Tool versions are pinned in [`mise.toml`](mise.toml).

## The pull requests

Each pull request isolates one kind of change, and its description says what
to look for. Their conversations are locked, so Atlantis' comments stay as
they were; to try a change of your own, fork the repository and run it
yourself.

| Pull request | Changes only | Atlantis plans |
| --- | --- | --- |
| [#1](https://github.com/shmileee/terramate-atlantis-autoplan/pull/1) | `stacks/aws/acme-development/account.tm.hcl` | the two stacks in that account |
| [#2](https://github.com/shmileee/terramate-atlantis-autoplan/pull/2) | `stacks/imports/aws.tm.hcl` | the four AWS stacks that import it |
| [#3](https://github.com/shmileee/terramate-atlantis-autoplan/pull/3) | `modules/shared/main.tf` | the two stacks that call it |
| [#4](https://github.com/shmileee/terramate-atlantis-autoplan/pull/4) | `config/settings.json` | the stack that lists it in `watch` |
| [#5](https://github.com/shmileee/terramate-atlantis-autoplan/pull/5) | the development `network` and `app` stacks | both; applying `app` first is refused |
| [#6](https://github.com/shmileee/terramate-atlantis-autoplan/pull/6) | a new stack's `stack.tm.hcl` and `main.tf` | the new stack |

## Running it yourself

Fork the repository, then:

```sh
mise install   # the pinned tools
make app       # once: create a GitHub App for Atlantis, install it on the fork
make up        # start Atlantis, reachable by GitHub through a free tunnel
make e2e       # open the example pull requests and check Atlantis' answers
make down
```
