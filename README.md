# T3System

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Environment variables

Local secrets live in `.envrc` (gitignored), loaded by [direnv](https://direnv.net/):

```bash
# Cloudinary (player profile pictures).
# Copy the "API environment variable" from the Cloudinary dashboard.
export CLOUDINARY_URL=cloudinary://<api_key>:<api_secret>@<cloud_name>
# Optional root folder for uploads, e.g. pictures go to t3_system_dev/players
export CLOUDINARY_FOLDER=t3_system_dev

# Fly.io deploys
export FLY_API_TOKEN=<token>
```

Run `direnv allow` after editing the file, then restart `mix phx.server`, since
these are read at startup.

The Cloudinary API key needs a role that can create and delete assets, otherwise
uploads fail with `Request forbidden due to missing permissions` (configure it in
the Cloudinary Console under the API key's roles).

In production, set the same Cloudinary variables as Fly secrets:

```bash
fly secrets set CLOUDINARY_URL=cloudinary://... CLOUDINARY_FOLDER=t3_system
```

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
