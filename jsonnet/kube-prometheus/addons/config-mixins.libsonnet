local imageName(image) =
  local parts = std.split(image, '/');
  local len = std.length(parts);
  if len == 3 then
    // registry.com/org/image
    parts[2]
  else if len == 2 then
    // org/image
    parts[1]
  else if len == 1 then
    // image, ie. busybox
    parts[0]
  else
    error 'unknown image format: ' + image;


// withImageRepository is a mixin that replaces all images prefixes by repository. eg.
// quay.io/coreos/addon-resizer -> $repository/addon-resizer
// grafana/grafana -> grafana $repository/grafana
local withImageRepository(repository) = {
  local oldRepos = super.values.common.images,
  local substituteRepository(image, repository) =
    if repository == null then image else repository + '/' + imageName(image),
  values+:: {
    common+:: {
      images:: {
        [field]: substituteRepository(oldRepos[field], repository)
        for field in std.objectFields(oldRepos)
      },
    },
  },
};

{
  withImageRepository:: withImageRepository,
}
