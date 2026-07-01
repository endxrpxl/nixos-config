final: prev: {
  vesktop = prev.vesktop.override {
    pnpm_10_29_2 = final.pnpm_10;
  };
  bitwarden-desktop = prev.bitwarden-desktop.override {
    electron_39 = final.electron_39-bin;
  };
}
