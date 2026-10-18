# frozen_string_literal: true

# simp-rspec-puppet-facts' `on_supported_os` only returns operating systems it
# ships captured facts for, and it ships none for Ubuntu, so Ubuntu entries in
# metadata.json are silently skipped. `all_supported_os` returns the
# simp-rspec-puppet-facts results plus facterdb facts (via rspec-puppet-facts)
# for every metadata.json operating system that simp-rspec-puppet-facts has no
# facts for. Those facts get symbol keys at every level, like the
# simp-rspec-puppet-facts ones, so specs can use `os_facts[:os][:family]` for
# either.
def all_supported_os(opts = {})
  simp_facts = on_supported_os(opts)
  known = simp_facts.keys.map { |k| k.split('-').first }.uniq

  missing = RspecPuppetFacts.meta_supported_os.reject do |os|
    known.include?(os['operatingsystem'].downcase.gsub(%r{\s}, '_'))
  end
  return simp_facts if missing.empty?

  extra = Simp::RspecPuppetFacts::Shim.on_supported_os(opts.merge(supported_os: missing))

  if ENV['SIMP_FACTS_OS'] && !ENV['SIMP_FACTS_OS'].strip.empty? && ENV['SIMP_FACTS_OS'] !~ %r{all}i
    filters = ENV['SIMP_FACTS_OS'].strip.split(%r{[ ,]+})
    extra.select! { |os, _| filters.any? { |str| os == str || os.match?(%r{#{str}}) } }
  end

  simp_facts.merge(extra.transform_values { |facts| deep_symbolize_fact_keys(facts) })
end

def deep_symbolize_fact_keys(value)
  case value
  when Hash then value.to_h { |k, v| [k.to_sym, deep_symbolize_fact_keys(v)] }
  when Array then value.map { |v| deep_symbolize_fact_keys(v) }
  else value
  end
end
