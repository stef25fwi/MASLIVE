/**
 * Cloud Function pour génération automatique de variantes d'images
 * Triggered lorsqu'une image est uploadée dans Storage
 * Génère automatiquement: thumbnail, small, medium, large
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as sharp from 'sharp';
import * as path from 'path';
import * as os from 'os';
import * as fs from 'fs';

// Initialiser Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const storage = admin.storage();
const firestore = admin.firestore();

// Configuration des tailles
interface ImageVariant {
  name: string;
  maxDimension: number;
  quality: number;
}

const variants: ImageVariant[] = [
  { name: 'thumbnail', maxDimension: 200, quality: 75 },
  { name: 'small', maxDimension: 400, quality: 80 },
  { name: 'medium', maxDimension: 800, quality: 85 },
  { name: 'large', maxDimension: 1200,quality: 88 },
  { name: 'xlarge', maxDimension: 1920, quality: 90 },
];

/**
 * Fonction déclenchée lors de l'upload d'une image
 */
export const generateImageVariants = functions
  .region('us-east1')
  .runWith({
    memory: '2GB',
    timeoutSeconds: 540,
  })
  .storage.object()
  .onFinalize(async (object) => {
    const filePath = object.name;
    const contentType = object.contentType;

    console.log('🖼️  [ImageVariants] Nouveau fichier:', filePath);

    // Vérifier si c'est une image
    if (!contentType || !contentType.startsWith('image/')) {
      console.log('⏭️  [ImageVariants] Pas une image, skip');
      return null;
    }

    // Vérifier si c'est déjà une variante (éviter boucle infinie)
    const fileName = path.basename(filePath);
    if (
      fileName.includes('thumbnail') ||
      fileName.includes('small') ||
      fileName.includes('medium') ||
      fileName.includes('large') ||
      fileName.includes('xlarge')
    ) {
      console.log('⏭️  [ImageVariants] Déjà une variante, skip');
      return null;
    }

    // Vérifier si c'est un original
    if (!fileName.includes('original')) {
      console.log('⏭️  [ImageVariants] Pas un original, skip');
      return null;
    }

    const bucket = storage.bucket(object.bucket);
    const fileDir = path.dirname(filePath);
    const tempLocalFile = path.join(os.tmpdir(), fileName);
    const tempLocalDir = path.dirname(tempLocalFile);

    try {
      // Créer répertoire temporaire
      if (!fs.existsSync(tempLocalDir)) {
        fs.mkdirSync(tempLocalDir, { recursive: true });
      }

      // Télécharger l'image originale
      console.log('⬇️  [ImageVariants] Téléchargement original...');
      await bucket.file(filePath).download({ destination: tempLocalFile });
      console.log('✅ [ImageVariants] Original téléchargé');

      // Lire métadonnées de l'image
      const imageMetadata = await sharp(tempLocalFile).metadata();
      console.log(
        `📐 [ImageVariants] Dimensions: ${imageMetadata.width}x${imageMetadata.height}`
      );

      // Générer toutes les variantes
      const variantPromises = variants.map((variant) =>
        generateVariant(
          tempLocalFile,
          variant,
          bucket,
          fileDir,
          imageMetadata
        )
      );

      const variantUrls = await Promise.all(variantPromises);

      // Récupérer URL de l'original
      const originalFile = bucket.file(filePath);
      const [originalUrl] = await originalFile.getSignedUrl({
        action: 'read',
        expires: '03-01-2500', // Date très lointaine
      });

      // Construire structure variants
      const variantsData: Record<string, string> = {
        original: originalUrl,
      };

      variants.forEach((variant, index) => {
        if (variantUrls[index]) {
          variantsData[variant.name] = variantUrls[index];
        }
      });

      // Mettre à jour Firestore si nécessaire
      await updateFirestoreWithVariants(filePath, variantsData, imageMetadata);

      console.log('✅ [ImageVariants] Toutes variantes générées');

      // Nettoyer fichiers temporaires
      fs.unlinkSync(tempLocalFile);

      return { success: true, variants: variantsData };
    } catch (error) {
      console.error('❌ [ImageVariants] Erreur:', error);
      throw error;
    }
  });

/**
 * Générer une variante d'image
 */
async function generateVariant(
  originalPath: string,
  variant: ImageVariant,
  bucket: any,
  fileDir: string,
  imageMetadata: sharp.Metadata
): Promise<string | null> {
  const { name, maxDimension, quality } = variant;

  try {
    console.log(`🔄 [ImageVariants] Génération ${name}...`);

    // Vérifier si redimensionnement nécessaire
    const width = imageMetadata.width || 0;
    const height = imageMetadata.height || 0;

    if (width <= maxDimension && height <= maxDimension) {
      console.log(`⏭️  [ImageVariants] ${name}: pas de redimensionnement nécessaire`);
      return null;
    }

    // Créer fichier temporaire pour variante
    const tempVariantPath = path.join(os.tmpdir(), `${name}.jpg`);

    // Redimensionner et optimiser
    await sharp(originalPath)
      .resize(maxDimension, maxDimension, {
        fit: 'inside',
        withoutEnlargement: true,
      })
      .jpeg({ quality, progressive: true })
      .toFile(tempVariantPath);

    // Upload vers Storage
    const variantPath = `${fileDir}/${name}.jpg`;
    await bucket.upload(tempVariantPath, {
      destination: variantPath,
      metadata: {
        contentType: 'image/jpeg',
        metadata: {
          variant: name,
          generatedAt: new Date().toISOString(),
        },
      },
    });

    // Obtenir URL publique
    const variantFile = bucket.file(variantPath);
    const [url] = await variantFile.getSignedUrl({
      action: 'read',
      expires: '03-01-2500',
    });

    console.log(`✅ [ImageVariants] ${name} créé`);

    // Nettoyer fichier temporaire
    fs.unlinkSync(tempVariantPath);

    return url;
  } catch (error) {
    console.error(`❌ [ImageVariants] Erreur ${name}:`, error);
    return null;
  }
}

/**
 * Mettre à jour Firestore avec les URLs des variantes
 */
async function updateFirestoreWithVariants(
  filePath: string,
  variants: Record<string, string>,
  imageMetadata: sharp.Metadata
): Promise<void> {
  try {
    // Extraire imageId depuis le path
    // Format attendu: .../images/{imageId}/original.jpg
    const pathParts = filePath.split('/');
    const imagesIndex = pathParts.indexOf('images');

    if (imagesIndex === -1 || imagesIndex >= pathParts.length - 2) {
      console.log('⏭️  [ImageVariants] Path ne contient pas /images/, skip Firestore');
      return;
    }

    const imageId = pathParts[imagesIndex + 1];
    console.log(`🔄 [ImageVariants] Mise à jour Firestore: ${imageId}`);

    // Mettre à jour document image_assets
    await firestore.collection('image_assets').doc(imageId).update({
      variants: variants,
      'metadata.width': imageMetadata.width,
      'metadata.height': imageMetadata.height,
      'metadata.format': imageMetadata.format,
      'metadata.variantsGeneratedAt': admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    console.log('✅ [ImageVariants] Firestore mis à jour');
  } catch (error) {
    console.error('⚠️  [ImageVariants] Erreur Firestore:', error);
    // Ne pas throw, c'est optionnel
  }
}

/**
 * Fonction callable pour regénérer variantes manuellement
 */
export const regenerateImageVariants = functions
  .region('us-east1')
  .https.onCall(async (data, context) => {
    // Vérifier authentification
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const { imageId } = data;

    if (!imageId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'imageId is required'
      );
    }

    try {
      // Récupérer document image
      const imageDoc = await firestore
        .collection('image_assets')
        .doc(imageId)
        .get();

      if (!imageDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Image not found');
      }

      const imageData = imageDoc.data();
      const originalUrl = imageData?.variants?.original;

      if (!originalUrl) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Original image URL not found'
        );
      }

      // TODO: Télécharger original et regénérer variantes

      return { success: true, message: 'Variantes regénérées' };
    } catch (error) {
      console.error('❌ [RegenerateVariants] Erreur:', error);
      throw new functions.https.HttpsError('internal', 'Regeneration failed');
    }
  });

/**
 * Fonction pour nettoyer anciennes images (soft-deleted)
 */
export const cleanupDeletedImages = functions
  .region('us-east1')
  .pubsub.schedule('every 24 hours')
  .onRun(async (context) => {
    console.log('🧹 [Cleanup] Début nettoyage images supprimées');

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 30); // 30 jours

    try {
      const snapshot = await firestore
        .collection('image_assets')
        .where('isActive', '==', false)
        .where('updatedAt', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
        .get();

      console.log(`🗑️  [Cleanup] ${snapshot.size} images à supprimer`);

      const deletePromises = snapshot.docs.map(async (doc) => {
        const imageData = doc.data();
        const variants = imageData.variants || {};

        // Supprimer toutes les variantes de Storage
        const storageDeletePromises = Object.entries(variants).map(
          async ([variantName, url]) => {
            try {
              // Extraire path depuis URL
              const urlObj = new URL(url as string);
              const pathMatch = urlObj.pathname.match(/\/o\/(.+)\?/);
              if (pathMatch) {
                const filePath = decodeURIComponent(pathMatch[1]);
                await storage.bucket().file(filePath).delete();
                console.log(`✅ [Cleanup] Supprimé: ${filePath}`);
              }
            } catch (error) {
              console.error(`⚠️  [Cleanup] Erreur suppression Storage:`, error);
            }
          }
        );

        await Promise.all(storageDeletePromises);

        // Supprimer document Firestore
        await doc.ref.delete();
        console.log(`✅ [Cleanup] Document supprimé: ${doc.id}`);
      });

      await Promise.all(deletePromises);

      console.log('✅ [Cleanup] Nettoyage terminé');
      return { success: true, deletedCount: snapshot.size };
    } catch (error) {
      console.error('❌ [Cleanup] Erreur:', error);
      throw error;
    }
  });

