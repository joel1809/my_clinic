package com.example.my_clinic

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    /**
     * Données de santé à l'écran : dossier médical, consultations, documents.
     * FLAG_SECURE interdit la capture et l'enregistrement d'écran, et masque
     * l'application dans la liste des applications récentes — sinon un aperçu
     * du dossier ouvert y resterait visible après la sortie de l'application.
     *
     * Écarté des builds de débogage : les captures promotionnelles
     * (integration_test/promo_screenshots_test.dart) ne rendraient qu'un écran
     * noir. Une build de distribution n'est jamais « debuggable ».
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val debuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
    }
}
