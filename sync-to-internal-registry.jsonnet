local l = import 'kube-prometheus/addons/config-mixins.libsonnet';
local kp = import 'kube-prometheus/main.libsonnet';
local config = kp.values.common;

local makeImages(config) = [
  {
    name: config.images[image],
  }
  for image in std.objectFields(config.images)
];

local upstreamImage(image) = '%s' % [image.name];
local downstreamImage(registry, image) = '%s/%s' % [registry, l.imageName(image.name)];

local pullPush(image, newRegistry) = [
  'docker pull %s' % upstreamImage(image),
  'docker tag %s %s' % [upstreamImage(image), downstreamImage(newRegistry, image)],
  'docker push %s' % downstreamImage(newRegistry, image),
];

local images = makeImages(config);

local output(repository) = std.flattenArrays([
  pullPush(image, repository)
  for image in images
]);

function(repository='my-registry.com/repository')
  std.join('\n', output(repository))
