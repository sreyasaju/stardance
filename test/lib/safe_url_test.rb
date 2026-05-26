require "test_helper"

class SafeUrlTest < ActiveSupport::TestCase
  def stub_resolv(addresses)
    original = Resolv.method(:getaddresses)
    Resolv.define_singleton_method(:getaddresses) { |_| addresses }
    yield
  ensure
    Resolv.define_singleton_method(:getaddresses, &original)
  end

  test "accepts a public https URL" do
    stub_resolv([ "140.82.121.4" ]) do
      assert SafeUrl.safe_to_probe?("https://github.com/example/repo")
    end
  end

  test "accepts a public http URL" do
    stub_resolv([ "93.184.216.34" ]) do
      assert SafeUrl.safe_to_probe?("http://example.com/path")
    end
  end

  test "rejects non-http schemes" do
    refute SafeUrl.safe_to_probe?("ftp://example.com")
    refute SafeUrl.safe_to_probe?("file:///etc/passwd")
    refute SafeUrl.safe_to_probe?("javascript:alert(1)")
    refute SafeUrl.safe_to_probe?("data:text/html,hi")
  end

  test "rejects blank or malformed URLs" do
    refute SafeUrl.safe_to_probe?(nil)
    refute SafeUrl.safe_to_probe?("")
    refute SafeUrl.safe_to_probe?("not a url")
    refute SafeUrl.safe_to_probe?("http://")
  end

  test "rejects loopback addresses" do
    stub_resolv([ "127.0.0.1" ]) { refute SafeUrl.safe_to_probe?("http://localhost/admin") }
    stub_resolv([ "::1" ]) { refute SafeUrl.safe_to_probe?("http://ip6-localhost/") }
  end

  test "rejects private RFC1918 ranges" do
    [ "10.0.0.1", "172.16.5.5", "192.168.1.1" ].each do |ip|
      stub_resolv([ ip ]) do
        refute SafeUrl.safe_to_probe?("http://internal.local/"), "expected #{ip} to be rejected"
      end
    end
  end

  test "rejects link-local (AWS metadata) addresses" do
    stub_resolv([ "169.254.169.254" ]) do
      refute SafeUrl.safe_to_probe?("http://aws-metadata/latest/meta-data/")
    end
  end

  test "rejects multicast and broadcast ranges" do
    stub_resolv([ "224.0.0.1" ]) { refute SafeUrl.safe_to_probe?("http://multicast/") }
    stub_resolv([ "0.0.0.0" ]) { refute SafeUrl.safe_to_probe?("http://zero/") }
  end

  test "rejects when any resolved address is private" do
    stub_resolv([ "8.8.8.8", "10.0.0.1" ]) do
      refute SafeUrl.safe_to_probe?("http://mixed/"), "must reject if any resolved IP is private"
    end
  end

  test "rejects when DNS resolution returns nothing" do
    stub_resolv([]) { refute SafeUrl.safe_to_probe?("http://nx.example.invalid/") }
  end

  test "accepts IP literal in URL when public" do
    stub_resolv([ "8.8.8.8" ]) { assert SafeUrl.safe_to_probe?("https://8.8.8.8/") }
  end

  test "rejects IP literal in URL when private" do
    stub_resolv([ "10.0.0.5" ]) { refute SafeUrl.safe_to_probe?("http://10.0.0.5/admin") }
  end
end
