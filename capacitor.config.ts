import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.davidmorales.pr",
  appName: "PR",
  webDir: "dist",
  android: {
    allowMixedContent: false,
  },
};

export default config;
