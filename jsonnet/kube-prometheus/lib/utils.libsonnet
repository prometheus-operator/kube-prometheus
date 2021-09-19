{
  // rangeInterval takes a scrape interval and convert its to a range interval
  // following Prometheus rule of thumb for rate() and irate().
  rangeInterval(i='1m'):
    local interval = std.parseInt(std.substr(i, 0, std.length(i) - 1));
    interval * 4 + i[std.length(i) - 1],
}
