FROM node:14-bullseye AS node-base

RUN apt-get update && apt-get install -y --no-install-recommends git unzip && rm -rf /var/lib/apt/lists/*
COPY hse-streaming-source-main-fixed.zip /tmp/source.zip
RUN mkdir -p /src /app/build && unzip -q /tmp/source.zip -d /src
RUN cp /src/hse-streaming-source-main/plugin/package.json /app/package.json && cp /src/hse-streaming-source-main/plugin/yarn.lock /app/yarn.lock
WORKDIR /app
RUN yarn install --frozen-lockfile --ignore-engines

FROM node-base AS plugin-build
RUN cp -R /src/hse-streaming-source-main/plugin/. /app/
RUN yarn build

FROM grafana/grafana:7.4.3 AS grafana
COPY --from=plugin-build /app/dist/ /var/lib/hse/hse-streaming-datasource
COPY --from=plugin-build /src/hse-streaming-source-main/grafana/provisioning/ /etc/grafana/provisioning/
COPY --from=plugin-build /src/hse-streaming-source-main/grafana/dashboards/ /var/lib/grafana/dashboards/
COPY --from=plugin-build /src/hse-streaming-source-main/grafana/run-and-copy.sh /run-and-copy.sh
ENV GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/var/lib/grafana/dashboards/test-dashboard.json
ENV GF_SERVER_HTTP_ADDR=0.0.0.0
USER grafana
ENTRYPOINT ["/bin/sh", "-c", "export GF_SERVER_HTTP_PORT=${PORT:-3000}; exec /run-and-copy.sh"]
