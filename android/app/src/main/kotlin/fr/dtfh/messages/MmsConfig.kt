package fr.dtfh.messages

import android.annotation.SuppressLint
import android.content.Context
import android.os.Build
import android.telephony.CarrierConfigManager
import android.telephony.SmsManager
import android.telephony.SubscriptionManager

/**
 * Configuration MMS publiée par l'opérateur.
 *
 * La taille maximale d'un MMS n'est pas une constante du protocole : chaque
 * opérateur pose la sienne, et Android la résout depuis l'application de
 * configuration opérateur, la SIM, ou ses propres valeurs par défaut. La lire
 * évite de comprimer trop — des photos dégradées pour rien — ou trop peu, des
 * messages que le MMSC refuse.
 *
 * Deux sources, dans cet ordre : [CarrierConfigManager], l'API dédiée, puis les
 * valeurs de [SmsManager], que certains appareils renseignent encore quand la
 * première ne dit rien.
 */
object MmsConfig {

    /**
     * @return la taille maximale d'un MMS en octets, ou `null` si rien
     * d'exploitable n'est publié — à l'appelant de choisir son repli.
     */
    fun maxMessageSize(context: Context): Int? =
        fromCarrierConfig(context) ?: fromSmsManager(context)

    private fun fromCarrierConfig(context: Context): Int? = runCatching {
        val manager = context.getSystemService(CarrierConfigManager::class.java)
            ?: return null
        val key = CarrierConfigManager.KEY_MMS_MAX_MESSAGE_SIZE_INT
        val config = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Depuis Android 13, la configuration se demande clé par clé pour
            // l'abonnement visé, ce qui évite de charger tout le bundle.
            manager.getConfigForSubId(smsSubscriptionId(), key)
        } else {
            @Suppress("DEPRECATION")
            manager.config
        }
        config?.getInt(key, 0)?.takeIf { it > 0 }
    }.getOrNull()

    /**
     * Repli historique : `getCarrierConfigValues` reste renseigné sur nombre
     * d'appareils là où la configuration dédiée est vide.
     */
    @SuppressLint("NewApi")
    private fun fromSmsManager(context: Context): Int? = runCatching {
        val manager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        manager?.carrierConfigValues
            ?.getInt(SmsManager.MMS_CONFIG_MAX_MESSAGE_SIZE, 0)
            ?.takeIf { it > 0 }
    }.getOrNull()

    /** L'abonnement qui sert aux SMS, ou celui par défaut du système. */
    private fun smsSubscriptionId(): Int {
        val id = SubscriptionManager.getDefaultSmsSubscriptionId()
        return if (id == SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
            SubscriptionManager.getDefaultSubscriptionId()
        } else {
            id
        }
    }
}
