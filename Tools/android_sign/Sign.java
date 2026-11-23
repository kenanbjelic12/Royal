import com.android.apksig.*;
import java.io.*;
import java.security.*;
import java.security.cert.X509Certificate;
import java.util.*;

/** Minimal apksigner replacement: sign/verify as Godot invokes them. */
public class Sign {
    public static void main(String[] a) throws Exception {
        if (a.length > 0 && a[0].equals("verify")) {
            File apk = new File(a[a.length - 1]);
            ApkVerifier.Result r = new ApkVerifier.Builder(apk).setMinCheckedPlatformVersion(24).build().verify();
            System.out.println("Verified: " + r.isVerified() + " v1=" + r.isVerifiedUsingV1Scheme() + " v2=" + r.isVerifiedUsingV2Scheme());
            for (Object e : r.getErrors()) System.err.println("ERROR: " + e);
            System.exit(r.isVerified() ? 0 : 1);
        }
        if (a.length == 0 || !a[0].equals("sign")) { System.out.println("apksigner (apksig 2.3.0 wrapper)"); return; }
        String ks = null, pass = "", alias = null, keyPass = null, out = null, in = null;
        for (int i = 1; i < a.length; i++) {
            switch (a[i]) {
                case "--ks": ks = a[++i]; break;
                case "--ks-pass": pass = a[++i].replaceFirst("^pass:", ""); break;
                case "--key-pass": keyPass = a[++i].replaceFirst("^pass:", ""); break;
                case "--ks-key-alias": alias = a[++i]; break;
                case "--out": out = a[++i]; break;
                case "--verbose": case "-v": break;
                case "--v1-signing-enabled": case "--v2-signing-enabled": case "--v3-signing-enabled": case "--min-sdk-version": i++; break;
                default: in = a[i];
            }
        }
        if (keyPass == null) keyPass = pass;
        KeyStore store = KeyStore.getInstance(KeyStore.getDefaultType());
        try (FileInputStream f = new FileInputStream(ks)) { store.load(f, pass.toCharArray()); }
        if (alias == null) alias = store.aliases().nextElement();
        PrivateKey key = (PrivateKey) store.getKey(alias, keyPass.toCharArray());
        X509Certificate cert = (X509Certificate) store.getCertificate(alias);
        ApkSigner.SignerConfig sc = new ApkSigner.SignerConfig.Builder("CERT", key, Collections.singletonList(cert)).build();
        File src = new File(in);
        File dst = out != null ? new File(out) : new File(in + ".signed");
        new ApkSigner.Builder(Collections.singletonList(sc)).setInputApk(src).setOutputApk(dst).setMinSdkVersion(24).setV1SigningEnabled(false).setV2SigningEnabled(true).build().sign();
        if (out == null) { src.delete(); dst.renameTo(src); }
        System.out.println("Signed");
    }
}
