# Tigris fee splitter maintainer

This component contains the implementation of a maintainer responsible for calling a `updatePeriod` function from contract `ChainFeeSplitter` in every new epoch to trigger the distribution of rewards. This component is written and deployed as a Cloudflare Worker.

### Prerequisites

Initially, you need to install the dependencies by running

```shell
npm install
```

### Development

Create the `.env` file and set `MAINTAINER_PRIVATE_KEY`. Note that it must be prefixed with `0x`.

You can start the development server by running:

```shell
npm run dev
```

The component will be available at `http://localhost:8001`. Code changes
are hot-reloaded by Wrangler.

To trigger the cron go to `http://localhost:8001/__scheduled?cron=<cron>` for example: `http://localhost:8001/__scheduled?cron=0+0+*+*+4`

### Deployment

Deploy the component to the staging environment by running:

```shell
npm run deploy:staging
```

Deploy the component to the production environment by running:

```shell
npm run deploy:production
```

Note that the `MAINTAINER_PRIVATE_KEY` env variable must be prefixed with `0x`.
