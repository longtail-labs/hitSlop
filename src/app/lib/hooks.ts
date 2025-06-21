import { useState, useEffect } from 'react';

export function useIsMobile() {
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkIsMobile = () => {
      // Check for mobile based on screen width and user agent
      const screenWidth = window.innerWidth;
      const userAgent = navigator.userAgent;
      
      // Consider mobile if screen width is less than 768px OR user agent indicates mobile
      const isMobileScreen = screenWidth < 768;
      const isMobileUserAgent = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(userAgent);
      
      setIsMobile(isMobileScreen || isMobileUserAgent);
    };

    // Check on mount
    checkIsMobile();

    // Listen for resize events
    window.addEventListener('resize', checkIsMobile);

    return () => {
      window.removeEventListener('resize', checkIsMobile);
    };
  }, []);

  return isMobile;
} 