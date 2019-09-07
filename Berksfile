require './lib/helpers'
source 'https://api.berkshelf.com'

solver :gecode, :preferred

github_cookbook 'ssmtp-lwrp', 'aspyatkin/ssmtp-lwrp-cookbook', tag: 'v0.1.0'
github_cookbook 'cronic', 'aspyatkin/cronic-cookbook', tag: 'v2.0.1'
github_cookbook 'volgactf-qualifier', 'VolgaCTF/volgactf-qualifier-cookbook', tag: 'v1.1.0'

local_cookbook 'volgactf-qualifier-main', './local-cookbooks/volgactf-qualifier-main'
