# Simple scripts to use Astro and Starlight from a container

You do not need to install [Node.js](https://nodejs.org/en) to use [Astro](https://astro.build/) or [Starlight](https://starlight.astro.build/) . Using `Node.js` from an official container is an easy task.

I use these scripts for development of `Astro` and `Starlight` based projects. For some explanations and detailed usage see:

- [Get started with Astro using containers](https://calinradoni.github.io/blog/astro_get_started_container)
- [Get started with Starlight using containers](https://calinradoni.github.io/blog/starlight_get_started_container)

## The scripts

### Project creation scripts

These are `create_astro_project.sh` and `create_starlight_project.sh`

Those scripts need the name of a new directory as parameter. The workflow is:

- Create a new directory and initialize a new `Astro` project inside
- Create a `notes` directory
- Add the `.vscode` and `notes` directories to `.gitignore`
- Modify `package.json` for safer access to `Astro`'s development server
- Download the helper scripts from `github.com/CalinRadoni/Scripts/raw/main/Astro`

### Development scripts

- `run_dev.sh` starts an `Astro` development server that listen for live file changes in the `src/` directory and updates the site, like the `astro dev` CLI command. Access the server at [http://localhost:4321](http://localhost:4321)
- `build.sh` builds the site for production. Use it before pushing your site in production to check for build errors.
- `preview_build.sh` starts an `Astro` development server for the site built by `build.sh` script. Access it at [http://localhost:4321](http://localhost:4321)
- `update_node_astro_packages.sh` updates the `Node.js` container, the packages and the `Astro` framework.

## Links

- [Astro Docs](https://docs.astro.build/en/getting-started/)
- [Starlight Docs](https://starlight.astro.build/getting-started/)
- [Podman Docs](https://docs.podman.io/en/latest/index.html)
