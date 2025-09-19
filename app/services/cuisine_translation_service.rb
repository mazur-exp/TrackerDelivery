class CuisineTranslationService
  # Static dictionary of Indonesian to English cuisine translations
  # Based on actual GoFood/GrabFood categories
  STATIC_TRANSLATIONS = {
    "aneka nasi" => "Rice",
    "ayam & bebek" => "Chicken & duck",
    "bakmie" => "Noodles",
    "bakso & soto" => "Bakso & soto",
    "barat" => "Western",
    "cepat saji" => "Fast food",
    "chinese" => "Chinese",
    "india" => "Indian",
    "indonesia" => "Indonesian",
    "jajanan" => "Snacks",
    "jepang" => "Japanese",
    "kopi" => "Coffee",
    "korea" => "Korean",
    "makanan sehat" => "Healthy",
    "martabak" => "Martabak",
    "minuman" => "Beverages",
    "nasi goreng" => "Fried Rice",
    "pizza & pasta" => "Pizza & pasta",
    "roti" => "Bakery",
    "sate" => "Sate",
    "seafood" => "Seafood",
    "steak" => "Steakhouse",
    "sweets" => "Sweets",
    "thailand" => "Thai",
    "timur tengah" => "Middle Eastern"
  }.freeze

  def self.translate(indonesian_text)
    return nil if indonesian_text.blank?
    
    normalized_text = indonesian_text.downcase.strip
    
    # 1. Check static dictionary first (fastest)
    static_translation = STATIC_TRANSLATIONS[normalized_text]
    return static_translation if static_translation
    
    # 2. Check database cache
    cached_translation = CuisineTranslation.find_by(indonesian: normalized_text)
    return cached_translation.english if cached_translation
    
    # 3. For now, return capitalized version as fallback
    # TODO: Add Google Translate API integration in future
    fallback_translation = indonesian_text.split.map(&:capitalize).join(' ')
    
    # Cache the fallback translation for future use
    begin
      CuisineTranslation.create!(
        indonesian: normalized_text,
        english: fallback_translation
      )
    rescue ActiveRecord::RecordNotUnique
      # Translation was created by another process, that's fine
    end
    
    fallback_translation
  end
  
  def self.translate_array(cuisines_array)
    return [] if cuisines_array.blank?
    
    cuisines_array.map { |cuisine| translate(cuisine) }.compact.uniq
  end
end