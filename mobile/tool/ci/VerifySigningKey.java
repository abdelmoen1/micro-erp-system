import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.Key;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.List;

public final class VerifySigningKey {
    private static final String EXPECTED_SHA256 =
            "C91F2920A374ABF73902A327125FE346BA50916390C0837DB080FB2059A6308B";

    private VerifySigningKey() {}

    public static void main(String[] args) {
        int exitCode = 0;
        char[] storePassword = null;
        char[] keyPassword = null;
        String actualSha256 = null;

        try {
            if (args.length != 1) {
                throw new IllegalArgumentException();
            }

            String alias = normalizedEnvironmentValue("KEY_ALIAS");
            storePassword = normalizedEnvironmentValue("KEYSTORE_PASSWORD").toCharArray();
            keyPassword = normalizedEnvironmentValue("KEY_PASSWORD").toCharArray();

            KeyStore keyStore = loadKeyStore(Path.of(args[0]), storePassword);

            if (!keyStore.isKeyEntry(alias)) {
                throw new IllegalArgumentException();
            }

            Certificate certificate = keyStore.getCertificate(alias);
            if (!(certificate instanceof X509Certificate)) {
                throw new IllegalArgumentException();
            }

            Key key = keyStore.getKey(alias, keyPassword);
            if (!(key instanceof PrivateKey)) {
                throw new IllegalArgumentException();
            }

            actualSha256 = HexFormat.of().withUpperCase().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(certificate.getEncoded()));
            if (!EXPECTED_SHA256.equals(actualSha256)) {
                System.err.println("::error::Production signing certificate fingerprint mismatch.");
                System.err.println("Expected SHA-256: " + EXPECTED_SHA256);
                System.err.println("Actual SHA-256:   " + actualSha256);
                exitCode = 1;
            }
        } catch (Exception exception) {
            System.err.println(
                    "::error::Could not open the production keystore with its configured alias and credentials.");
            exitCode = 1;
        } finally {
            if (storePassword != null) {
                Arrays.fill(storePassword, '\0');
            }
            if (keyPassword != null) {
                Arrays.fill(keyPassword, '\0');
            }
        }

        if (exitCode == 0) {
            System.out.println(
                    "Production signing certificate verified: SHA-256 " + actualSha256);
        } else {
            System.exit(exitCode);
        }
    }

    private static String normalizedEnvironmentValue(String name) {
        String value = System.getenv(name);
        if (value == null || value.isEmpty()) {
            throw new IllegalArgumentException();
        }
        if (value.startsWith("\uFEFF")) {
            value = value.substring(1);
        }
        while (value.endsWith("\r") || value.endsWith("\n")) {
            value = value.substring(0, value.length() - 1);
        }
        if (value.isEmpty()) {
            throw new IllegalArgumentException();
        }
        return value;
    }

    private static KeyStore loadKeyStore(Path path, char[] storePassword) throws Exception {
        for (String type : List.of("PKCS12", "JKS")) {
            KeyStore keyStore = KeyStore.getInstance(type);
            try (InputStream input = Files.newInputStream(path)) {
                keyStore.load(input, storePassword);
                return keyStore;
            } catch (Exception exception) {
                // Try the other standard Android keystore format without exposing provider details.
            }
        }
        throw new IllegalArgumentException();
    }
}
