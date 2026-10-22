<?php

namespace Tests\Unit;

use PHPUnit\Framework\TestCase;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;

/**
 * US-0106 contract freeze: every error code the backend can emit is
 * documented in docs/api/error-codes.md, which the mobile client maps.
 */
class ErrorCodeContractTest extends TestCase
{
    private const DOC = __DIR__ . '/../../../docs/api/error-codes.md';

    public function test_every_emitted_error_code_is_documented(): void
    {
        $this->assertFileExists(self::DOC);
        $documented = $this->documentedCodes();

        $emitted = $this->emittedCodes();
        $this->assertNotEmpty($emitted, 'No error codes found in app/; the scan pattern is broken.');

        $missing = array_values(array_diff($emitted, $documented));
        $this->assertSame([], $missing, 'Error codes missing from docs/api/error-codes.md: ' . implode(', ', $missing));
    }

    public function test_documented_codes_are_still_emitted(): void
    {
        $stale = array_values(array_diff($this->documentedCodes(), $this->emittedCodes(), ['HTTP_<status>']));

        $this->assertSame([], $stale, 'Documented codes no longer emitted by the backend: ' . implode(', ', $stale));
    }

    /** @return list<string> */
    private function documentedCodes(): array
    {
        preg_match_all('/^\|[^|]*\|\s*`([A-Z][A-Z_<>a-z]+)`\s*\|/m', file_get_contents(self::DOC), $m);

        return array_values(array_unique($m[1]));
    }

    /** @return list<string> */
    private function emittedCodes(): array
    {
        $codes = [];
        $files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator(__DIR__ . '/../../app'));

        foreach ($files as $file) {
            if ($file->getExtension() !== 'php') {
                continue;
            }

            $source = file_get_contents($file->getPathname());

            // new ApiException(403, 'USER_INACTIVE', ...), ApiException::businessRule('CODE', ...)
            // and ApiException::conflict('CODE', ...)
            preg_match_all("/ApiException\(\s*\d{3},\s*'([A-Z_]+)'/", $source, $direct);
            preg_match_all("/(?:businessRule|conflict)\(\s*'([A-Z_]+)'/", $source, $business);
            $codes = array_merge($codes, $direct[1], $business[1]);

            if (str_ends_with($file->getFilename(), 'ApiExceptionRenderer.php')) {
                // Status map entries and literal codes returned by describe().
                preg_match_all("/=>\s*'([A-Z][A-Z_]+)'/", $source, $mapped);
                preg_match_all("/\[\s*(?:\d{3}|\\\$status),\s*'([A-Z][A-Z_]+)'/", $source, $literal);
                $codes = array_merge($codes, $mapped[1], $literal[1]);
            }
        }

        return array_values(array_unique($codes));
    }
}
