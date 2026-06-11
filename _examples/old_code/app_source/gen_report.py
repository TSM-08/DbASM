from app_source.app_base import AppBase
from .as_schema import SchemaAssessment


class MigrationReport:
    def __init__(self, config: dict, report_code: str, assessment: SchemaAssessment):
        self._config = config.get("assessment", {})
        self._report_code = report_code
        self._report_name = self._config.get(report_code, {}).get('name', 'Migration Assessment Report')
        self._data_query = self._config.get(report_code, {}).get('data_query', {})
        self._report_items = self._config.get(report_code, {}).get('items', {})
        self._show_statistics = self._config.get(report_code, {}).get('show_statistics', True)
        self._assessment = assessment
        
        # Statistics tracking
        self._total_rules = 0
        self._total_passed = 0
        self._total_failed = 0
        self._section_stats = {}
        self._status = "PASS"
        self._description = None

    def generate_report(self) -> str:
        """
        Generate the complete migration assessment report.
        
        Returns:
            str: The complete report content.
        """
        report_lines = []
        
        report_lines.append(f"*** {self._report_name} ***".center(AppBase.SECTION_LENGTH))
        report_lines.append("-"*AppBase.SECTION_LENGTH)

        # Reset statistics
        self._total_rules = 0
        self._total_passed = 0
        self._total_failed = 0
        self._status = "PASS"
        self._description = None

        self._section_stats = {}
        for section, details in self._report_items.items():
            title = details.get('title', f"Section {section}") + ' '
            rules = details.get('rules', [])

            mark = ''
            status, rule_details = self.check_section_status(rules)
            if status == "Fail":
                self._status = "FAIL"
                mark = ' *'
            report_lines.append(f"\n{section}. {title.ljust(AppBase.SECTION_LENGTH-8, '.')} {status.upper()}{mark}")

            # Track section statistics using section code (A, B, C...)
            section_passed = sum(1 for rule in rule_details if rule['result'])
            section_failed = sum(1 for rule in rule_details if not rule['result'])
            section_total = len(rule_details)

            self._section_stats[section] = {
                'code': section,  # Store the section code (A, B, C...)
                'title': details.get('title', f"Section {section}"),
                'total': section_total,
                'passed': section_passed,
                'failed': section_failed,
                'status': status
            }
            
            for rule in rule_details:
                rule_id = rule.get('id', 'Unknown')
                rule_title = rule.get('title', 'No Title')
                severity = rule.get('severity', 'Unknown')
                rule_result = rule.get('result', False)

                report_lines.append(f" - [{rule_id}] {rule_title}".ljust(AppBase.SECTION_LENGTH - 13, ' ') + 
                    f" {severity:<7} {'(OK)' if rule_result else '(No)'} ")

        # Add statistics
        if self._show_statistics:
            report_lines.extend(self._get_statistics_lines())
        
        # Add summary
        report_lines.extend(self._get_summary_lines())
        
        # Return the complete report as a string
        return "\n".join(report_lines)

    def _get_summary_lines(self) -> list:
        """Generate summary lines."""
        lines = []
        overall_success_rate = (self._total_passed / self._total_rules * 100) if self._total_rules > 0 else 0
        overall_status = self._status
        
        lines.append("\n" + "-"*AppBase.SECTION_LENGTH)
        lines.append("*** ASSESSMENT SUMMARY ***".center(AppBase.SECTION_LENGTH))
        lines.append("-"*AppBase.SECTION_LENGTH)
        lines.append(f"[T] Total Rules Evaluated: {self._total_rules}")
        lines.append(f"[P] Rules Passed: {self._total_passed}")
        lines.append(f"[F] Rules Failed: {self._total_failed}")
        lines.append(f"[R] Success Rate: {overall_success_rate:.1f}%")
        lines.append(f"[S] Overall Status: {overall_status}")

        if self._status == "FAIL":
            self._description = f"NOT READY - {self._total_failed} issues need attention"
            lines.append(f"\nMigration readiness: {self._description}")
        else:
            self._description = "READY - All important checks passed!"
            lines.append(f"\nMigration readiness: {self._description}")
        
        # lines.append("="*AppBase.SECTION_LENGTH)
        
        return lines

    def _get_statistics_lines(self) -> list:
        """Generate statistics lines."""
        lines = []
        
        lines.append("\n" + "="*AppBase.SECTION_LENGTH)
        lines.append("*** MIGRATION ASSESSMENT STATISTICS ***".center(AppBase.SECTION_LENGTH))
        lines.append("="*AppBase.SECTION_LENGTH)
        
        # Section-wise statistics using section codes
        lines.append(f"\n{'Section':<10} {'Total':<8} {'Passed':<8} {'Failed':<8} {'Success %':<12} {'Status':<8}")
        lines.append("-" * AppBase.SECTION_LENGTH)
        
        for section_code, stats in self._section_stats.items():
            total = stats['total']
            passed = stats['passed']
            failed = stats['failed']
            success_rate = (passed / total * 100) if total > 0 else 0
            status = stats['status']
            
            lines.append(f"{section_code:<10} {total:<8} {passed:<8} {failed:<8} {success_rate:<12.1f} {status:<8}")
        
        # Overall statistics
        lines.append("-" * AppBase.SECTION_LENGTH)
        overall_success_rate = (self._total_passed / self._total_rules * 100) if self._total_rules > 0 else 0
        overall_status = self._status
        
        lines.append(f"{'OVERALL':<10} {self._total_rules:<8} {self._total_passed:<8} {self._total_failed:<8} {overall_success_rate:<12.1f} {overall_status:<8}")
        
        return lines
        
    def check_section_status(self, rules: list[dict]):
        """
        Returns overall section status and a list of rule details.
        Each rule detail is a dict with id, severity, title, and result.
        """
        all_passed = True
        titles = self._config.get(self._data_query, {})
        details = []

        for rule in rules:
            for rule_id, severity in rule.items():
                title = titles.get(rule_id, "No Title")

                rule_success = self.check_rule_status(rule_id, severity)
                
                # Update overall statistics
                self._total_rules += 1
                if rule_success:
                    self._total_passed += 1
                else:
                    self._total_failed += 1
                
                # Determine if this rule affects section status
                if not rule_success and severity.lower() in ('low', 'medium'):
                    pass  # Low/Medium failures don't fail the section
                else:
                    all_passed = all_passed and rule_success
                
                details.append({
                    'id': rule_id,
                    'severity': severity,
                    'title': title,
                    'result': rule_success
                })

        return ("Pass" if all_passed else "Fail"), details

    def check_rule_status(self, rule_id: str, severity: str) -> bool:
        """ Check if a specific rule passed or failed. """
        success = False
        if (result := self._assessment.get_data_by_id(self._data_query, rule_id)):
            success = not (result[1] and len(result[1]) > 0)
        return success

    def get_statistics(self) -> dict:
        """
        Get comprehensive statistics as a dictionary.
        
        Returns:
            dict: Statistics including totals, section breakdown, and success rates.
        """
        overall_success_rate = (self._total_passed / self._total_rules * 100) if self._total_rules > 0 else 0
        
        return {
            'overall': {
                'total_checks': self._total_rules,
                'total_passed': self._total_passed,
                'total_failed': self._total_failed,
                'success_rate': round(overall_success_rate, 2),
                'migration_success': self._status == "PASS",
                'status': self._status,
                'db_readiness': self._description
            },
            'sections': self._section_stats
        }