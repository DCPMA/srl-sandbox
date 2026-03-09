# typed: false
# frozen_string_literal: true

class SrlSandbox < Formula
  desc "Sandboxed dev environments using Apple Container (macOS 26+)"
  homepage "https://github.com/DCPMA/srl-sandbox"
  url "https://github.com/DCPMA/srl-sandbox/archive/refs/tags/v2.5.0.tar.gz"
  sha256 "af3c4d04d18218e7920ab59a42a790ed52316b7baece0349ac2f849589887a47"
  license "MIT"

  head "https://github.com/DCPMA/srl-sandbox.git", branch: "main"

  depends_on :macos

  def install
    # Install the main CLI script
    bin.install "srl-sandbox"

    # Install the Containerfile alongside the script in share
    pkgshare.install "Containerfile"

    # Patch the script to find the Containerfile in the share directory
    inreplace bin/"srl-sandbox",
              'readonly SCRIPT_DIR="${0:A:h}"',
              "readonly SCRIPT_DIR=\"#{pkgshare}\""

    # Install zsh completions
    zsh_completion.install "completions/_srl-sandbox"

    # Install documentation
    doc.install "README.md" if File.exist?("README.md")
  end

  def caveats
    <<~EOS
      srl-sandbox requires:
        • macOS 26+ (Tahoe) with Apple Silicon
        • Apple Container CLI: https://github.com/apple/container

      Install Apple Container CLI:
        brew install container

      Build the sandbox image after installation:
        srl-sandbox build

      SSH key passphrase tip:
        If VS Code prompts for your SSH key passphrase, run:
          ssh-add --apple-use-keychain ~/.ssh/id_ed25519
    EOS
  end

  test do
    # Verify the CLI runs and reports the correct version
    assert_match "srl-sandbox v#{version}", shell_output("#{bin}/srl-sandbox version")

    # Verify help output contains expected commands
    help_output = shell_output("#{bin}/srl-sandbox help")
    assert_match "launch", help_output
    assert_match "stop", help_output
    assert_match "destroy", help_output
    assert_match "reset", help_output
    assert_match "Apple Container", help_output
  end
end
